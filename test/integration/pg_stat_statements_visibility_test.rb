require "test_helper"

class PgStatStatementsVisibilityTest < ActionDispatch::IntegrationTest
  setup do
    @database = PgPeek::Database.find("primary")
    @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)
  end

  test "shows warning with generator command when pg_stat_statements is available but not installed" do
    skip "pg_stat_statements not available on this server" unless @pg_stat_statements.available?

    # Ensure extension is not installed
    drop_extension_if_exists

    get pg_peek.database_path(@database)

    assert_response :success
    assert_select "article[aria-label='Extension pg_stat_statements is not enabled']" do
      assert_select "header", text: "pg_stat_statements extension is not enabled"
      assert_select "code", text: /enable_extension "pg_stat_statements"/
    end
    assert_select "a[href='#{pg_peek.database_pg_stat_statements_path(@database)}']", text: "pg_stat_statements", count: 0
  end

  test "shows link to pg_stat_statements when extension is installed and preloaded" do
    skip "pg_stat_statements not available on this server" unless @pg_stat_statements.available?

    # Ensure extension is not installed first
    drop_extension_if_exists

    # Install the extension
    @database.connection.execute("CREATE EXTENSION pg_stat_statements")

    get pg_peek.database_path(@database)

    assert_response :success
    assert_select "article[aria-label='Extension pg_stat_statements is not available']", count: 0

    if PgPeek::PgStatStatements.new(database: @database).preloaded?
      assert_select "a[href='#{pg_peek.database_pg_stat_statements_path(@database)}']", text: "pg_stat_statements"
    else
      # Installed but never loaded at server start: the link would only lead to
      # a view that cannot be queried, so the instructions are shown instead.
      assert_select "a[href='#{pg_peek.database_pg_stat_statements_path(@database)}']", count: 0
      assert_select "article[aria-label='Extension pg_stat_statements is not preloaded']"
    end
  ensure
    drop_extension_if_exists
  end

  private

  def drop_extension_if_exists
    @database.connection.execute("DROP EXTENSION IF EXISTS pg_stat_statements")
  rescue ActiveRecord::StatementInvalid
    # Ignore errors if extension doesn't exist or can't be dropped
  end
end
