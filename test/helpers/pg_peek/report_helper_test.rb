require "test_helper"

class PgPeek::ReportHelperTest < ActionView::TestCase
  include PgPeek::ReportHelper
  include PgPeek::ApplicationHelper

  class SampleReport < PgPeek::Report
    column :name
    column :calls, align: :right, format: :number
    column :total_time, align: :right, format: :duration_ms
    column :share, align: :right, format: :percent
    column :query, format: :sql
    column :weight, align: :right, format: :intensity

    def fetch_rows
      [ { "name" => "A", "calls" => "1234", "total_time" => "2500", "share" => "40.0",
          "query" => "SELECT 1 /*job='X'*/", "weight" => "10" },
        { "name" => "B", "calls" => "7", "total_time" => "0", "share" => "1.0",
          "query" => "SELECT 2", "weight" => "5" } ]
    end
  end

  setup do
    @report = SampleReport.new(database: PgPeek::Database.find("primary"))
  end

  test "renders text untouched" do
    assert_equal "A", cell(:name, 0)
  end

  test "delimits numbers" do
    assert_equal "1,234", cell(:calls, 0)
  end

  test "formats millisecond durations" do
    assert_equal "00:00:02.500", cell(:total_time, 0)
  end

  test "appends a percent sign" do
    assert_equal "40.0%", cell(:share, 0)
  end

  test "strips sqlcommenter from sql cells" do
    assert_includes cell(:query, 0), "SELECT 1"
    assert_not_includes cell(:query, 0), "job='X'"
  end

  test "scales an intensity cell against the column maximum" do
    # 10 of a maximum 10 fills every segment; 5 of 10 fills half, rounded up.
    assert_equal 5, filled(cell(:weight, 0))
    assert_equal 3, filled(cell(:weight, 1))
  end

  test "reports the largest value in a column" do
    assert_equal 10.0, @report.max_for(@report.columns.last)
  end

  test "renders nothing for a missing value rather than the word nil" do
    assert_equal "", format_cell(@report, @report.columns.first, PgPeek::Report::Row.new({}))
  end

  private

  def column(key) = @report.columns.find { |c| c.key == key }
  def cell(key, index) = format_cell(@report, column(key), @report.rows[index]).to_s
  def filled(markup) = markup[/class="bar-on">([█]*)</, 1].to_s.size
end
