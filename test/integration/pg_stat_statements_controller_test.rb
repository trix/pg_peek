require "test_helper"
require "minitest/mock"

class PgStatStatementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @database = PgPeek::Database.find("primary")
    install_pg_stat_statements(@database)
    @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)
  end

  test "reset returns to the overview block that owns the statistics" do
    skip_unless_usable(@pg_stat_statements)

    # The real reset is server-wide and would wipe the development statistics
    # on a shared server, so the call is recorded rather than executed.
    resets = 0
    @pg_stat_statements.define_singleton_method(:reset!) { resets += 1 }

    PgPeek::PgStatStatements.stub(:new, @pg_stat_statements) do
      delete pg_peek.reset_database_pg_stat_statements_path(@database)

      assert_redirected_to pg_peek.database_path(@database, anchor: "pg_stat_statements")
      follow_redirect!
    end

    assert_equal 1, resets
    assert_select "p.notice", text: /has been reset/
    assert_select "section#pg_stat_statements form[action='#{pg_peek.reset_database_pg_stat_statements_path(@database)}']"
  end
end
