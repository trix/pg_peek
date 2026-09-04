require "test_helper"
require "minitest/mock"

class PgPeek::PgStatStatementsTest < ActiveSupport::TestCase
  setup do
    @database = PgPeek::Database.find("primary")
    @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)
  end

  test "shared_preload_libraries reads the setting from the server" do
    assert_kind_of String, @pg_stat_statements.shared_preload_libraries
  end

  test "preloaded? agrees with the setting the server reports" do
    expected = @pg_stat_statements.shared_preload_libraries.include?(PgPeek::PgStatStatements::LIBRARY_NAME)

    assert_equal expected, @pg_stat_statements.preloaded?
  end

  test "preloaded? is false when shared_preload_libraries is empty" do
    @pg_stat_statements.stub(:shared_preload_libraries, "") do
      assert_not @pg_stat_statements.preloaded?
    end
  end

  test "preloaded? is true when listed among several libraries" do
    @pg_stat_statements.stub(:shared_preload_libraries, "pg_cron, pg_stat_statements, auto_explain") do
      assert @pg_stat_statements.preloaded?
    end
  end

  test "preloaded? is false when another library merely has a similar name" do
    @pg_stat_statements.stub(:shared_preload_libraries, "pg_stat_statements_extra") do
      assert_not @pg_stat_statements.preloaded?
    end
  end

  test "usable? is false when the extension is installed but not preloaded" do
    skip "pg_stat_statements not available on this server" unless @pg_stat_statements.available?

    @pg_stat_statements.stub(:preloaded?, false) do
      assert_not @pg_stat_statements.usable?
    end
  end

  test "outliers returns nil instead of raising when not preloaded" do
    @pg_stat_statements.stub(:preloaded?, false) do
      assert_nil @pg_stat_statements.outliers
    end
  end

  test "jobs returns nil instead of raising when not preloaded" do
    @pg_stat_statements.stub(:preloaded?, false) do
      assert_nil @pg_stat_statements.jobs
    end
  end

  test "outliers_by_job returns nil instead of raising when not preloaded" do
    @pg_stat_statements.stub(:preloaded?, false) do
      assert_nil @pg_stat_statements.outliers_by_job("SomeJob")
    end
  end

  test "reset_at returns nil instead of raising when not preloaded" do
    @pg_stat_statements.stub(:preloaded?, false) do
      assert_nil @pg_stat_statements.reset_at
    end
  end

  test "reset_at reads from its own database rather than the primary" do
    analytics = PgPeek::Database.find("analytics")
    skip "analytics database not configured" unless analytics&.connection_configured?

    analytics_stat = PgPeek::PgStatStatements.new(database: analytics)
    skip "pg_stat_statements not usable on this server" unless analytics_stat.usable?

    # pg_stat_statements_info holds one cluster-wide value, so reading it through
    # the wrong connection returns the same thing on a single server. Removing the
    # extension from the primary makes the wrong connection fail loudly instead.
    # The transactional test rolls the drop back afterwards.
    ActiveRecord::Base.connection.execute("DROP EXTENSION IF EXISTS pg_stat_statements")

    expected = analytics.connection.execute("SELECT stats_reset FROM pg_stat_statements_info").first["stats_reset"]

    assert_equal expected, analytics_stat.reset_at
  end
end
