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

  test "index links a namespaced endpoint to its page" do
    skip_unless_usable(@pg_stat_statements)

    get "/admin/posts"
    get pg_peek.database_endpoints_path(@database)

    assert_response :success
    assert_select "a[href='/pg_peek/databases/primary/endpoints/admin/posts/index']", text: "admin/posts#index"
  end

  test "show lists the queries of one endpoint and not of others" do
    skip_unless_usable(@pg_stat_statements)

    get "/posts"
    get "/admin/posts"
    get pg_peek.database_endpoint_path(@database, endpoint_controller: "admin/posts", endpoint_action: "index")

    assert_response :success
    assert_select "h1 code.name", text: "admin/posts#index"
    assert_select "a", text: "← endpoints"
    assert_select "td code.sql", text: /position/
    assert_select "td code.sql", text: /LIMIT/, count: 0
  end

  test "show does not list a namespaced endpoint under its plain controller name" do
    skip_unless_usable(@pg_stat_statements)

    get "/posts"
    get "/admin/posts"
    get pg_peek.database_endpoint_path(@database, endpoint_controller: "posts", endpoint_action: "index")

    assert_response :success
    assert_select "td code.sql", text: /LIMIT/, minimum: 1
    assert_select "td code.sql", text: /position/, count: 0
  end

  test "show explains an endpoint without queries" do
    skip_unless_usable(@pg_stat_statements)

    get pg_peek.database_endpoint_path(@database, endpoint_controller: "missing", endpoint_action: "index")

    assert_response :success
    assert_select "h1 code.name", text: "missing#index"
    assert_select "article[aria-label='No queries found']"
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
