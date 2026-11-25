require "test_helper"
require "minitest/mock"

class PgPeek::EndpointsTest < ActiveSupport::TestCase
  setup do
    @database = PgPeek::Database.find("primary")
    install_pg_stat_statements(@database)
    @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)
  end

  test "endpoints returns nil instead of raising when not preloaded" do
    @pg_stat_statements.stub(:preloaded?, false) do
      assert_nil @pg_stat_statements.endpoints
    end
  end

  test "endpoints runs against the server and returns the expected shape" do
    skip_unless_usable(@pg_stat_statements)

    rows = @pg_stat_statements.endpoints

    assert_kind_of Array, rows
    rows.each do |row|
      assert_includes row["endpoint"], "#"
      assert_operator row["request_count"].to_i, :>, 0
      assert_operator row["max_queries_per_request"].to_f, :>=, 1
    end
  end

  test "a NOTIFY per request does not pass for the request count" do
    skip_unless_usable(@pg_stat_statements)

    controller, table = unclaimed_names
    tags = "/*action='index',controller='#{controller}'*/"
    connection = @database.connection
    connection.execute("CREATE TEMP TABLE #{table} (id integer)")

    3.times do |request|
      connection.execute("SELECT count(*) FROM #{table} #{tags}")
      # Every payload is a statement of its own, called once.
      connection.execute("NOTIFY #{table}, 'request #{request}' #{tags}")
    end

    endpoint = with_outliers_limit(10_000) { @pg_stat_statements.endpoints }
                 .find { |row| row["endpoint"] == "#{controller}#index" }

    assert_equal 3, endpoint["request_count"].to_i
    assert_equal 1, endpoint["query_count"].to_i
  end

  test "leaves the statements the host calls unattributed out of an endpoint" do
    skip_unless_usable(@pg_stat_statements)

    controller, table = unclaimed_names
    tags = "/*action='index',controller='#{controller}'*/"
    connection = @database.connection
    connection.execute("CREATE TEMP TABLE #{table} (id integer)")
    connection.execute("CREATE TEMP TABLE #{table}_shared (id integer)")
    connection.execute("CREATE TEMP TABLE #{table}_queue (id integer)")
    [ table, "#{table}_shared", "#{table}_queue" ].each do |name|
      connection.execute("SELECT count(*) FROM #{name} #{tags}")
    end

    shapes = with_unattributed_queries([ "#{table}_shared", /FROM #{table}_QUEUE/i ]) do
      @pg_stat_statements.outliers_by_endpoint("#{controller}#index").map { |row| row["query"] }
    end

    assert_equal 1, shapes.size
    assert_match(/FROM #{table} /, shapes.first)
    assert_equal 3, @pg_stat_statements.outliers_by_endpoint("#{controller}#index").size
  end

  test "leaves unattributed statements out of a job" do
    skip_unless_usable(@pg_stat_statements)

    job, table = unclaimed_names
    tags = "/*job='#{job}'*/"
    connection = @database.connection
    connection.execute("CREATE TEMP TABLE #{table} (id integer)")
    connection.execute("CREATE TEMP TABLE #{table}_shared (id integer)")
    connection.execute("SELECT count(*) FROM #{table} #{tags}")
    connection.execute("SELECT count(*) FROM #{table}_shared #{tags}")
    connection.execute("NOTIFY #{table} #{tags}")

    with_unattributed_queries([ "#{table}_shared" ]) do
      row = @pg_stat_statements.jobs.find { |candidate| candidate["job_class"] == job }
      shapes = @pg_stat_statements.outliers_by_job(job).map { |candidate| candidate["query"] }

      assert_equal 1, row["query_count"].to_i
      assert_equal 1, shapes.size
      assert_match(/FROM #{table} /, shapes.first)
    end
  end

  test "the queries page still lists unattributed statements" do
    skip_unless_usable(@pg_stat_statements)

    _, table = unclaimed_names
    @database.connection.execute("NOTIFY #{table}")

    queries = with_outliers_limit(10_000) { @pg_stat_statements.outliers }.map { |row| row["query"] }

    assert queries.any? { |query| query.start_with?("NOTIFY #{table}") }, "NOTIFY #{table} is not listed"
  end

  test "shared statements lists what the breakdowns leave out, and only that" do
    skip_unless_usable(@pg_stat_statements)

    controller, table = unclaimed_names
    tags = "/*action='index',controller='#{controller}'*/"
    connection = @database.connection
    connection.execute("CREATE TEMP TABLE #{table} (id integer)")
    connection.execute("CREATE TEMP TABLE #{table}_queue (id integer)")
    connection.execute("SELECT count(*) FROM #{table} #{tags}")
    connection.execute("SELECT count(*) FROM #{table}_queue #{tags}")
    connection.execute("NOTIFY #{table} #{tags}")

    # Not the bare table name: CREATE TABLE mentions it as well.
    shared = with_unattributed_queries([ "FROM #{table}_queue" ]) do
      with_outliers_limit(10_000) { @pg_stat_statements.shared_statements }
    end
    mine = shared.map { |row| row["query"] }.select { |query| query.include?(table) }

    assert_equal 2, mine.size
    assert mine.any? { |query| query.start_with?("NOTIFY #{table}") }
    assert mine.any? { |query| query.include?("FROM #{table}_queue") }
  end

  test "the shared summary grows by the statements that become shared" do
    skip_unless_usable(@pg_stat_statements)

    _, table = unclaimed_names
    connection = @database.connection
    connection.execute("CREATE TEMP TABLE #{table}_queue (id integer)")
    2.times { connection.execute("SELECT count(*) FROM #{table}_queue") }

    before = @pg_stat_statements.shared_summary
    after = with_unattributed_queries([ "FROM #{table}_queue" ]) { @pg_stat_statements.shared_summary }

    assert_equal before["statement_count"].to_i + 1, after["statement_count"].to_i
    assert_equal before["calls"].to_i + 2, after["calls"].to_i
    assert_operator after["exec_time_ms"].to_f, :<=, after["all_exec_time_ms"].to_f
  end

  test "endpoints are named controller#action" do
    skip_unless_usable(@pg_stat_statements)

    # Deliberately no query here. pg_stat_statements keys on queryid, which
    # ignores comments, so an untagged run of a shape another test tags would
    # claim that shape's single row and strip the attribution.
    endpoints = @pg_stat_statements.endpoints.map { |row| row["endpoint"] }

    assert endpoints.all? { |name| name.count("#") == 1 }, endpoints.inspect
  end

  private
    # pg_stat_statements keys on queryid, which ignores comments, and keeps the
    # text of the first call. A shape another test has already run would carry
    # that test's tags, so every test here gets a controller and a table nothing
    # else can have claimed.
    def unclaimed_names
      suffix = SecureRandom.hex(4)
      [ "peek_attribution_#{suffix}", "peek_attribution_table_#{suffix}" ]
    end

    def with_unattributed_queries(patterns)
      original = PgPeek.config.unattributed_queries
      PgPeek.config.unattributed_queries = patterns
      yield
    ensure
      PgPeek.config.unattributed_queries = original
    end

    def with_outliers_limit(limit)
      original = PgPeek.config.outliers_limit
      PgPeek.config.outliers_limit = limit
      yield
    ensure
      PgPeek.config.outliers_limit = original
    end
end
