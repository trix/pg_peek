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

  test "endpoints are named controller#action" do
    skip_unless_usable(@pg_stat_statements)

    # Deliberately no query here. pg_stat_statements keys on queryid, which
    # ignores comments, so an untagged run of a shape another test tags would
    # claim that shape's single row and strip the attribution.
    endpoints = @pg_stat_statements.endpoints.map { |row| row["endpoint"] }

    assert endpoints.all? { |name| name.count("#") == 1 }, endpoints.inspect
  end
end
