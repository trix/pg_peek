require "test_helper"

class PgPeek::IndexesTest < ActiveSupport::TestCase
  setup do
    @database = PgPeek::Database.find("primary")
  end

  test "lists every index on user tables with size and scan count" do
    rows = PgPeek::Reports::Indexes.new(database: @database).rows

    assert rows.any?
    assert rows.any? { |row| row["index_name"] == "posts_pkey" }
    rows.each do |row|
      assert row["size"].present?
      assert_match(/\A\d+\z/, row["scans"].to_s)
    end
  end

  test "flags a never-scanned index that enforces nothing as unused" do
    @database.connection.execute("CREATE INDEX index_posts_on_body_for_test ON posts (body)")

    report = PgPeek::Reports::Indexes.new(database: @database)

    assert_includes report.unused.map { |row| row["index_name"] }, "index_posts_on_body_for_test"
    assert_equal "unused", report.rows.first["note"], "unused indexes sort first"
  end

  test "never counts a primary key or unique index as unused" do
    report = PgPeek::Reports::Indexes.new(database: @database)
    pkey = report.rows.find { |row| row["index_name"] == "posts_pkey" }

    assert_equal "primary key", pkey["kind"]
    assert_not_includes report.unused, pkey
  end

  test "leaves indexes on excluded tables out" do
    names = PgPeek::Reports::Indexes.new(database: @database).rows.map { |row| row["table_name"] }

    assert_not_includes names, "schema_migrations"
    assert_not_includes names, "ar_internal_metadata"
  end
end
