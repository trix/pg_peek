require "test_helper"

class PgPeek::QueryLoaderTest < ActiveSupport::TestCase
  test "every loaded query carries the marker" do
    sql = PgPeek::QueryLoader.load("pg_stat_statements/outliers", pg_version: 17, limit: 5)

    assert sql.end_with?(PgPeek::QueryLoader::MARKER), sql[-40..]
  end

  test "mark drops a trailing semicolon so the comment stays inside the statement" do
    assert_equal "SELECT 1 /* pg_peek */", PgPeek::QueryLoader.mark("SELECT 1;\n")
  end

  test "mark is idempotent" do
    once = PgPeek::QueryLoader.mark("SELECT 1")

    assert_equal once, PgPeek::QueryLoader.mark(once)
  end
end
