require "test_helper"

# pg_peek may be mounted in an app whose role can read little beyond its own
# database. Whatever it may not see, it says so; it never answers with a 500.
class UnprivilegedRoleTest < ActionDispatch::IntegrationTest
  setup do
    @database = PgPeek::Database.find("primary")
    install_pg_stat_statements(@database)
    become_unprivileged_role(@database)
  end

  test "every page renders" do
    [
      pg_peek.databases_path,
      pg_peek.database_path(@database),
      pg_peek.database_queries_path(@database),
      pg_peek.database_endpoints_path(@database),
      pg_peek.database_jobs_path(@database),
      pg_peek.database_job_path(@database, "PostAnalyticsJob"),
      pg_peek.database_indexes_path(@database),
      pg_peek.database_activity_path(@database),
      pg_peek.database_table_path(@database, "posts")
    ].each do |path|
      get path
      assert_response :success, "#{path} did not render"
    end
  end

  test "the overview disables the reset and says why" do
    skip_unless_usable(PgPeek::PgStatStatements.new(database: @database))

    get pg_peek.database_path(@database)

    assert_select "section#pg_stat_statements" do
      assert_select "button[disabled]", text: "reset statistics"
      assert_select "p", text: /peek_unprivileged may not reset/
      assert_select "code", text: "GRANT EXECUTE ON FUNCTION pg_stat_statements_reset TO peek_unprivileged;"
    end
  end

  test "a reset it may not run is refused, not raised" do
    skip_unless_usable(PgPeek::PgStatStatements.new(database: @database))

    delete pg_peek.reset_database_pg_stat_statements_path(@database)

    assert_redirected_to pg_peek.database_path(@database, anchor: "pg_stat_statements")
    follow_redirect!
    assert_select "p.alert", text: /may not reset/
  end
end
