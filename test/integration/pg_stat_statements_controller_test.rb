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
    assert_select "section#settings summary code", text: "pg_stat_statements.max"
    assert_select "section#reset form[action='#{pg_peek.reset_database_pg_stat_statements_path(@database)}']"
    # The dummy keeps all its databases on one server, as a review app would.
    assert_select "section#reset p", text: /also clears primary_replica, queue, and analytics/
  end

  test "show warns in a panel when the server has dropped statements" do
    skip_unless_usable(@pg_stat_statements)
    full = PgPeek::PgStatStatements.new(database: @database)
    full.define_singleton_method(:dealloc) { 1934 }

    PgPeek::PgStatStatements.stub(:new, full) do
      get pg_peek.database_pg_stat_statements_path(@database)
    end

    assert_select "article[aria-label='Statements dropped']" do
      assert_select "header", text: "1,934 statements dropped since the last reset"
      assert_select "p", text: /every total in pg_peek undercounts/
      assert_select "code", text: "pg_stat_statements.max"
    end
  end

  test "show has no such panel while there is room" do
    skip_unless_usable(@pg_stat_statements)
    roomy = PgPeek::PgStatStatements.new(database: @database)
    roomy.define_singleton_method(:dealloc) { 0 }

    PgPeek::PgStatStatements.stub(:new, roomy) do
      get pg_peek.database_pg_stat_statements_path(@database)
    end

    assert_select "article[aria-label='Statements dropped']", count: 0
  end

  test "show explains each setting in a row that opens" do
    skip_unless_usable(@pg_stat_statements)

    get pg_peek.database_pg_stat_statements_path(@database)

    assert_select "section#settings details.setting", count: 5
    assert_select "section#settings details.setting summary .info", count: 5

    assert_select "section#settings details.setting", text: /pg_stat_statements\.max/ do
      assert_select "summary code", text: "pg_stat_statements.max"
      assert_select "summary .value", text: /\A\d+\z/
      assert_select ".about", text: /least-executed statements are dropped/
      assert_select ".about", text: /From 100\s+to 1,073,741,823/
      assert_select ".about", text: /Default\s+5000.*needs a server restart/m
    end

    assert_select "section#settings details.setting", text: /pg_stat_statements\.track\b/ do
      assert_select "dt code", text: "top"
      assert_select "dt code", text: "all"
      assert_select "dt code", text: "none"
      assert_select "dd", text: /counted twice/
    end
  end

  test "show says a restart clears the statistics only when they are not saved" do
    skip_unless_usable(@pg_stat_statements)

    get pg_peek.database_pg_stat_statements_path(@database)
    assert_select "section#reset p", text: /Restarting PostgreSQL/, count: 0

    unsaved = PgPeek::PgStatStatements.new(database: @database)
    switched_off = PgPeek::PgStatStatements::Setting.new(
      "name" => "pg_stat_statements.save", "setting" => "off", "vartype" => "bool", "boot_val" => "on", "context" => "sighup"
    )
    unsaved.define_singleton_method(:setting_details) { [ switched_off ] }

    PgPeek::PgStatStatements.stub(:new, unsaved) do
      get pg_peek.database_pg_stat_statements_path(@database)
    end
    assert_select "section#reset p", text: /Restarting PostgreSQL clears them too/
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
