require "test_helper"
require "minitest/mock"

class EndpointsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @database = PgPeek::Database.find("primary")
    install_pg_stat_statements(@database)
    @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)
  end

  test "index renders the endpoints report when the extension is usable" do
    skip_unless_usable(@pg_stat_statements)

    # pg_peek's own requests are excluded from its statistics, so the traffic
    # has to come from the host application: the dummy's posts#index.
    get "/posts"
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
