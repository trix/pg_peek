require "test_helper"
require "minitest/mock"

class QueriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @database = PgPeek::Database.find("primary")
    install_pg_stat_statements(@database)
    @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)
  end

  test "index renders the query list when the extension is usable" do
    skip_unless_usable(@pg_stat_statements)

    get pg_peek.database_queries_path(@database)

    assert_response :success
    assert_select "h1", text: "queries"
    assert_select "article[aria-label='Extension pg_stat_statements is not preloaded']", count: 0
    # The reset lives on the overview; this page only points at it.
    assert_select "form[action='#{pg_peek.reset_database_pg_stat_statements_path(@database)}']", count: 0
    assert_select "a[href='#{pg_peek.database_path(@database, anchor: "pg_stat_statements")}']", text: /stats since/
  end

  test "index links a query's SQLcommenter tags to their source and shows the raw tags" do
    tagged = PgPeek::PgStatStatements.new(database: @database)
    tagged.define_singleton_method(:usable?) { true }
    tagged.define_singleton_method(:outliers) do
      [ {
        "ncalls" => "5", "total_exec_time" => "00:00:00.01", "prop_exec_time" => "100.0%",
        "avg_exec_ms" => "2",
        "query" => "SELECT 1 /*controller='posts',action='index'*/"
      } ]
    end

    PgPeek::PgStatStatements.stub(:new, tagged) do
      get pg_peek.database_queries_path(@database)
    end

    assert_response :success
    assert_select "a[href='/pg_peek/databases/primary/endpoints/posts/index']", text: "posts#index"
    assert_select "details.tags summary", text: "tags"
    assert_select "details.tags pre", text: /controller: posts/
  end

  test "index shows the call count next to its bar and a sub-millisecond average" do
    listed = PgPeek::PgStatStatements.new(database: @database)
    listed.define_singleton_method(:usable?) { true }
    listed.define_singleton_method(:outliers) do
      [ { "ncalls" => "1,234", "total_exec_time" => "00:00:00.05", "prop_exec_time" => "100.0%",
          "avg_exec_ms" => "0.0405", "query" => "SELECT 1" } ]
    end

    PgPeek::PgStatStatements.stub(:new, listed) do
      get pg_peek.database_queries_path(@database)
    end

    assert_response :success
    assert_select "thead th.num", text: "calls"
    assert_select "tbody td.num", text: /\A\s*1,234 █████\s*\z/
    assert_select "tbody td.num span", text: "0.041ms"
  end

  test "index renders preload instructions when the module is not preloaded" do
    not_preloaded = PgPeek::PgStatStatements.new(database: @database)
    not_preloaded.define_singleton_method(:preloaded?) { false }
    not_preloaded.define_singleton_method(:shared_preload_libraries) { "" }

    PgPeek::PgStatStatements.stub(:new, not_preloaded) do
      get pg_peek.database_queries_path(@database)
    end

    assert_response :success
    assert_select "article[aria-label='Extension pg_stat_statements is not preloaded']" do
      assert_select "header", text: "pg_stat_statements is not loaded"
      assert_select "code", text: /shared_preload_libraries = 'pg_stat_statements'/
    end
    assert_select "table", count: 0
  end

  test "database show links to queries only when it is usable" do
    not_preloaded = PgPeek::PgStatStatements.new(database: @database)
    not_preloaded.define_singleton_method(:preloaded?) { false }
    not_preloaded.define_singleton_method(:shared_preload_libraries) { "" }

    PgPeek::PgStatStatements.stub(:new, not_preloaded) do
      get pg_peek.database_path(@database)
    end

    assert_response :success
    assert_select "article[aria-label='Extension pg_stat_statements is not preloaded']"
    # The nav still offers the section; the body must not link to a page that
    # would only repeat the instructions already shown here.
    assert_select "a[href='#{pg_peek.database_queries_path(@database)}']", text: "pg_stat_statements", count: 0
  end
end
