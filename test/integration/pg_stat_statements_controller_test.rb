require "test_helper"
require "minitest/mock"

class PgStatStatementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @database = PgPeek::Database.find("primary")
    install_pg_stat_statements(@database)
    @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)
  end

  test "outliers renders the query list when the extension is usable" do
    skip_unless_usable(@pg_stat_statements)

    get pg_peek.database_pg_stat_statements_path(@database)

    assert_response :success
    assert_select "h1", text: "Outliers"
    assert_select "article[aria-label='Extension pg_stat_statements is not preloaded']", count: 0
  end

  test "outliers renders preload instructions when the module is not preloaded" do
    not_preloaded = PgPeek::PgStatStatements.new(database: @database)
    not_preloaded.define_singleton_method(:preloaded?) { false }
    not_preloaded.define_singleton_method(:shared_preload_libraries) { "" }

    PgPeek::PgStatStatements.stub(:new, not_preloaded) do
      get pg_peek.database_pg_stat_statements_path(@database)
    end

    assert_response :success
    assert_select "article[aria-label='Extension pg_stat_statements is not preloaded']" do
      assert_select "header", text: "pg_stat_statements is not loaded"
      assert_select "code", text: /shared_preload_libraries = 'pg_stat_statements'/
    end
    assert_select "table", count: 0
  end

  test "database show links to pg_stat_statements only when it is usable" do
    not_preloaded = PgPeek::PgStatStatements.new(database: @database)
    not_preloaded.define_singleton_method(:preloaded?) { false }
    not_preloaded.define_singleton_method(:shared_preload_libraries) { "" }

    PgPeek::PgStatStatements.stub(:new, not_preloaded) do
      get pg_peek.database_path(@database)
    end

    assert_response :success
    assert_select "article[aria-label='Extension pg_stat_statements is not preloaded']"
    assert_select "a[href='#{pg_peek.database_pg_stat_statements_path(@database)}']", count: 0
  end
end
