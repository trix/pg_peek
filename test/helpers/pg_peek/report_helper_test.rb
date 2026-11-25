require "test_helper"

class PgPeek::ReportHelperTest < ActionView::TestCase
  include PgPeek::Engine.routes.url_helpers
  include PgPeek::ReportHelper
  include PgPeek::ApplicationHelper

  class SampleReport < PgPeek::Report
    column :name
    column :calls, align: :right, format: :number
    column :total_time, align: :right, format: :duration_ms
    column :share, align: :right, format: :percent
    column :query, format: :sql
    column :weight, align: :right, format: :number, bar: true

    def fetch_rows
      [ { "name" => "A", "calls" => "1234", "total_time" => "2500", "share" => "40.0",
          "query" => "SELECT 1 /*job='X'*/", "weight" => "10" },
        { "name" => "B", "calls" => "7", "total_time" => "0", "share" => "1.0",
          "query" => "SELECT 2 /*controller='posts',action='index'*/", "weight" => "5" },
        { "name" => "C", "calls" => "3", "total_time" => "0", "share" => "0.0",
          "query" => "SELECT 3", "weight" => "1" } ]
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

  test "formats millisecond durations compactly, with the exact figure on hover" do
    assert_includes cell(:total_time, 0), ">2.50s<"
    assert_includes cell(:total_time, 0), 'title="2,500.0 ms"'
  end

  test "appends a percent sign" do
    assert_equal "40.0%", cell(:share, 0)
  end

  test "strips sqlcommenter from sql cells" do
    assert_includes cell(:query, 0), "SELECT 1"
    assert_not_includes cell(:query, 0), "job='X'"
  end

  test "links a sql cell's job tag to the job's own page" do
    markup = cell(:query, 0)

    assert_includes markup, "→"
    assert_includes markup, %(href="#{database_job_path(@report.database, "X")}")
    assert_includes markup, ">X<"
  end

  test "links a sql cell's controller tag to the endpoint page" do
    markup = cell(:query, 1)

    assert_includes markup, %(href="/pg_peek/databases/primary/endpoints/posts/index")
    assert_includes markup, ">posts#index<"
  end

  test "shows the full raw tags behind a details disclosure" do
    markup = cell(:query, 0)

    assert_includes markup, "<details"
    assert_includes markup, "<summary>tags</summary>"
    assert_includes markup, "job: X"
  end

  test "sql cells without a sqlcommenter tag show no source or disclosure" do
    markup = cell(:query, 2)

    assert_not_includes markup, "→"
    assert_not_includes markup, "<details"
  end

  test "shows a sub-millisecond duration as <1ms, with the exact figure on hover" do
    row = PgPeek::Report::Row.new("total_time" => "0.0437")

    markup = format_cell(@report, column(:total_time), row).to_s
    assert_includes markup, ">&lt;1ms<"
    assert_includes markup, 'title="0.044 ms"'
  end

  test "scales a bar against the column maximum" do
    # 10 of a maximum 10 fills every segment; 5 of 10 fills half, rounded up.
    assert_equal 5, filled(cell(:weight, 0))
    assert_equal 3, filled(cell(:weight, 1))
  end

  test "shows the value itself in front of its bar" do
    assert cell(:weight, 1).start_with?("5 <span class=\"bar bar-3\">")
  end

  test "columns without a bar draw none" do
    assert_not_includes cell(:calls, 0), "bar"
  end

  test "right-aligns a barred column like any other figure" do
    assert_equal "num", cell_class(column(:weight))
  end

  test "reports the largest value in a column" do
    assert_equal 10.0, @report.max_for(@report.columns.last)
  end

  test "splits an endpoint name after the last slash" do
    assert_equal [ "courier_company_app/dashboard/", "executions#show" ],
                 name_parts("courier_company_app/dashboard/executions#show")
  end

  test "leaves an endpoint without a namespace whole" do
    assert_equal [ nil, "posts#index" ], name_parts("posts#index")
  end

  test "splits a job name after the last double colon" do
    assert_equal [ "GDPR::OrderAnonymizationBatch::", "ProgressMonitorJob" ],
                 name_parts("GDPR::OrderAnonymizationBatch::ProgressMonitorJob")
  end

  test "leaves a top-level job whole" do
    assert_equal [ nil, "PostDigestJob" ], name_parts("PostDigestJob")
  end

  test "renders a name with its namespace dimmed and the full name on hover" do
    markup = name_cell("Reports::PostSummaryJob")

    assert_includes markup, 'title="Reports::PostSummaryJob"'
    assert_includes markup, '<span class="namespace"><span>Reports::</span></span>'
    assert_includes markup, '<span class="leaf">PostSummaryJob</span>'
  end

  test "renders nothing for a missing value rather than the word nil" do
    assert_equal "", format_cell(@report, @report.columns.first, PgPeek::Report::Row.new({}))
  end

  private

  def column(key) = @report.columns.find { |c| c.key == key }
  def cell(key, index) = format_cell(@report, column(key), @report.rows[index]).to_s
  def filled(markup) = markup[/class="bar-on">([█]*)</, 1].to_s.size
end
