require "test_helper"

class ReplicaMarkerTest < ActionDispatch::IntegrationTest
  setup do
    @database = PgPeek::Database.find("primary")
  end

  test "a primary carries no marker" do
    get pg_peek.database_path(@database)

    assert_response :success
    assert_select ".replica", count: 0
  end

  test "the overview names a replica beside the database and among its vitals" do
    on_a_replica { get pg_peek.database_path(@database) }

    assert_response :success
    assert_select "nav .current-database .replica", text: "replica"
    assert_select "p.vitals span.replica", text: "replica"
  end

  test "every page names a replica beside the database" do
    on_a_replica { get pg_peek.database_tables_path(@database) }

    assert_select "nav .current-database .replica", text: "replica"
  end

  test "the indexes page says a replica's scan counts are its own" do
    get pg_peek.database_indexes_path(@database)
    assert_select "[data-replica-note]", count: 0

    on_a_replica { get pg_peek.database_indexes_path(@database) }
    assert_select "[data-replica-note]", text: /may be in use on the primary/
  end

  test "the list of databases gives a replica its role" do
    on_a_replica { get pg_peek.databases_path }

    assert_select "td", text: "replica", minimum: 1
  end

  test "the overview no longer dumps the database's configuration" do
    get pg_peek.database_path(@database)

    assert_select "summary", text: "database details", count: 0
    assert_select "summary", text: "installed extensions"
  end

  private
    # No standby to test against, so the server's answer is put in its mouth.
    def on_a_replica
      original = PgPeek::Database.instance_method(:replica?)
      PgPeek::Database.define_method(:replica?) { true }
      yield
    ensure
      PgPeek::Database.define_method(:replica?, original)
    end
end
