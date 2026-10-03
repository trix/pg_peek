require "test_helper"

class PgPeek::SqlFormatTest < ActiveSupport::TestCase
  test "starts each clause and join on its own line, and each condition indented" do
    query = <<~SQL.squish
      SELECT DISTINCT "control_stops".* FROM "control_stops"
      INNER JOIN "control_jobs" ON "control_jobs"."stop_id" = "control_stops"."id"
      LEFT OUTER JOIN "control_tours" ON "control_tours"."id" = "control_stops"."tour_id"
      WHERE "control_stops"."done_at" IS NULL AND "control_jobs"."type" = $1
      AND "control_stops"."starts_at" BETWEEN $2 AND $3 ORDER BY "control_stops"."id" LIMIT $4
    SQL

    assert_equal <<~SQL.chomp, PgPeek::SqlFormat.format(query)
      SELECT DISTINCT "control_stops".*
      FROM "control_stops"
      INNER JOIN "control_jobs" ON "control_jobs"."stop_id" = "control_stops"."id"
      LEFT OUTER JOIN "control_tours" ON "control_tours"."id" = "control_stops"."tour_id"
      WHERE "control_stops"."done_at" IS NULL
        AND "control_jobs"."type" = $1
        AND "control_stops"."starts_at" BETWEEN $2 AND $3
      ORDER BY "control_stops"."id"
      LIMIT $4
    SQL
  end

  test "leaves parentheses, CASE and quotes on one line" do
    query = <<~SQL.squish
      SELECT CASE WHEN a AND b THEN 1 END, 'x FROM y AND z' FROM t
      WHERE (( a = $1 AND b = $2 ) OR c IN (SELECT id FROM u WHERE d)) AND e
    SQL

    assert_equal <<~SQL.chomp, PgPeek::SqlFormat.format(query)
      SELECT CASE WHEN a AND b THEN 1 END, 'x FROM y AND z'
      FROM t
      WHERE (( a = $1 AND b = $2 ) OR c IN (SELECT id FROM u WHERE d))
        AND e
    SQL
  end

  test "joins conditions stay on the join's line" do
    query = "SELECT 1 FROM a JOIN b ON b.a_id = a.id AND b.kind = $1 WHERE a.x = $2"

    assert_equal "SELECT 1\nFROM a\nJOIN b ON b.a_id = a.id AND b.kind = $1\nWHERE a.x = $2",
                 PgPeek::SqlFormat.format(query)
  end

  test "keeps a function named like a join keyword where it is" do
    assert_equal "SELECT left(name, $1)\nFROM t", PgPeek::SqlFormat.format("SELECT left(name, $1) FROM t")
  end

  test "collapses existing line breaks and spacing" do
    assert_equal "SELECT 1\nFROM t", PgPeek::SqlFormat.format("  SELECT 1\n\n   FROM   t  ")
  end

  test "keeps a short query on one line" do
    assert_equal "BEGIN", PgPeek::SqlFormat.format("BEGIN")
  end
end
