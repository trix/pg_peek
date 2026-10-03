require "test_helper"
require "minitest/mock"

class PgStatStatementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @database = PgPeek::Database.find("primary")
    install_pg_stat_statements(@database)
    @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)
  end

  test "show describes the collection, its settings and the reset" do
    skip_unless_usable(@pg_stat_statements)

    get pg_peek.database_pg_stat_statements_path(@database)

    assert_response :success
    assert_select "h1", text: /pg_stat_statements/
    assert_select "th", text: "dropped when full"
    assert_select "th code", text: "pg_stat_statements.max"
    assert_select "section#reset form[action='#{pg_peek.reset_database_pg_stat_statements_path(@database)}']"
    # The dummy keeps all its databases on one server, as a review app would.
    assert_select "section#reset p", text: /also clears queue and analytics/
  end

  test "show renders preload instructions when the module is not preloaded" do
    PgPeek::PgStatStatements.stub(:new, not_preloaded_stat_statements) do
      get pg_peek.database_pg_stat_statements_path(@database)
    end

    assert_response :success
    assert_select "article[aria-label='Extension pg_stat_statements is not preloaded']"
  end

  test "reset returns to the extension page" do
    skip_unless_usable(@pg_stat_statements)

    # The real reset is server-wide and would wipe the development statistics
    # on a shared server, so the call is recorded rather than executed.
    resets = 0
    @pg_stat_statements.define_singleton_method(:reset!) { resets += 1 }

    PgPeek::PgStatStatements.stub(:new, @pg_stat_statements) do
      delete pg_peek.reset_database_pg_stat_statements_path(@database)

      assert_redirected_to pg_peek.database_pg_stat_statements_path(@database)
      follow_redirect!
    end

    assert_equal 1, resets
    assert_select "p.notice", text: /has been reset/
    assert_select "section#reset form[action='#{pg_peek.reset_database_pg_stat_statements_path(@database)}']"
  end

  private

  def not_preloaded_stat_statements
    PgPeek::PgStatStatements.new(database: @database).tap do |pg_stat|
      pg_stat.define_singleton_method(:preloaded?) { false }
      pg_stat.define_singleton_method(:shared_preload_libraries) { "" }
    end
  end
end
