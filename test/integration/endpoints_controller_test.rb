require "test_helper"
require "minitest/mock"

class EndpointsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @database = PgPeek::Database.find("primary")
    @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)
    @pg_stat_statements.install! if @pg_stat_statements.available?
  end

  test "index renders the endpoints report when the extension is usable" do
    skip_unless_usable(@pg_stat_statements)

    # Any request through the engine tags its own queries, so after one visit
    # there is at least one endpoint to list.
    get pg_peek.database_path(@database)
    get pg_peek.database_endpoints_path(@database)

    assert_response :success
    assert_select "h1", text: "endpoints"
    assert_select "th", text: "q/req"
    assert_select "tbody tr", minimum: 1
  end

  test "index renders preload instructions when the module is not preloaded" do
    not_preloaded = PgPeek::PgStatStatements.new(database: @database)
    not_preloaded.define_singleton_method(:preloaded?) { false }
    not_preloaded.define_singleton_method(:shared_preload_libraries) { "" }

    PgPeek::PgStatStatements.stub(:new, not_preloaded) do
      get pg_peek.database_endpoints_path(@database)
    end

    assert_response :success
    assert_select "article[aria-label='Extension pg_stat_statements is not preloaded']"
    assert_select "table", count: 0
  end
end
