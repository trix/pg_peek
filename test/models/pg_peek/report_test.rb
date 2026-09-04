require "test_helper"

class PgPeek::ReportTest < ActiveSupport::TestCase
  class StubReport < PgPeek::Report
    title "Stub"

    column :name, header: "job class"
    column :calls, align: :right, format: :number
    column :total_time, header: "db time", align: :right, format: :duration_ms

    def fetch_rows
      [ { "name" => "PostPublishJob", "calls" => "1234", "total_time" => "2500" } ]
    end
  end

  class EmptyReport < StubReport
    def fetch_rows = []
  end

  setup do
    @database = PgPeek::Database.find("primary")
  end

  test "exposes its declared columns in order" do
    report = StubReport.new(database: @database)

    assert_equal %i[name calls total_time], report.columns.map(&:key)
  end

  test "derives a header from the key when none is given" do
    report = StubReport.new(database: @database)

    assert_equal "total time", PgPeek::Column.new(:total_time).header
    assert_equal "db time", report.columns.last.header
  end

  test "keeps alignment and format on the column" do
    calls = StubReport.new(database: @database).columns.second

    assert_equal :right, calls.align
    assert_equal :number, calls.format
  end

  test "defaults to left aligned text" do
    column = PgPeek::Column.new(:anything)

    assert_equal :left, column.align
    assert_equal :text, column.format
  end

  test "reads values out of a row by column key" do
    report = StubReport.new(database: @database)
    row = report.rows.first

    assert_equal "PostPublishJob", row.value(report.columns.first)
  end

  test "memoizes rows so a report is not fetched twice per render" do
    report = StubReport.new(database: @database)

    assert_same report.rows, report.rows
  end

  test "knows when it has nothing to show" do
    assert_not StubReport.new(database: @database).empty?
    assert EmptyReport.new(database: @database).empty?
  end

  test "carries a title" do
    assert_equal "Stub", StubReport.title
  end
end
