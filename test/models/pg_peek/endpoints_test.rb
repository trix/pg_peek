require "test_helper"
require "minitest/mock"

class PgPeek::EndpointsTest < ActiveSupport::TestCase
  setup do
    @database = PgPeek::Database.find("primary")
    @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)
    @pg_stat_statements.install! if @pg_stat_statements.available?
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

  test "endpoints attributes a request to the action that issued it" do
    skip_unless_usable(@pg_stat_statements)

    # A request through the engine tags its own queries, which is the same
    # mechanism a host application's endpoints go through.
    Post.order(:id).limit(1).to_a

    endpoints = @pg_stat_statements.endpoints.map { |row| row["endpoint"] }

    assert endpoints.all? { |name| name.count("#") == 1 }, endpoints.inspect
  end
end
