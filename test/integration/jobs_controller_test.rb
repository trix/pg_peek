require "test_helper"
require "minitest/mock"

class JobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @database = PgPeek::Database.find("primary")
    install_pg_stat_statements(@database)
    @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)
  end

  test "index renders when the extension is usable" do
    skip_unless_usable(@pg_stat_statements)

    get pg_peek.database_jobs_path(@database)

    assert_response :success
    assert_select "h1", text: "jobs"
    assert_select "article[aria-label='Extension pg_stat_statements is not preloaded']", count: 0
  end

  test "index renders preload instructions when the module is not preloaded" do
    PgPeek::PgStatStatements.stub(:new, not_preloaded_stat_statements) do
      get pg_peek.database_jobs_path(@database)
    end

    assert_response :success
    assert_select "article[aria-label='Extension pg_stat_statements is not preloaded']"
  end

  test "index does not also blame missing jobs when the module is not preloaded" do
    PgPeek::PgStatStatements.stub(:new, not_preloaded_stat_statements) do
      get pg_peek.database_jobs_path(@database)
    end

    # Showing "no jobs found" alongside the preload instructions points at the
    # wrong problem: there are no statistics at all, not merely no job queries.
    assert_select "article[aria-label='No jobs found']", count: 0
  end

  test "index names the missing job tag as the cause when it is not configured" do
    skip_unless_usable(@pg_stat_statements)

    PgPeek::PgStatStatements.stub(:new, no_jobs_stat_statements) do
      with_query_log_tags [ :application, :controller, :action ] do
        get pg_peek.database_jobs_path(@database)
      end
    end

    assert_response :success
    assert_select "article[aria-label='Job tag not configured']"
    assert_select "article[aria-label='No jobs have run yet']", count: 0
  end

  test "index blames the statistics reset when the job tag is configured" do
    skip_unless_usable(@pg_stat_statements)

    PgPeek::PgStatStatements.stub(:new, no_jobs_stat_statements) do
      get pg_peek.database_jobs_path(@database)
    end

    assert_response :success
    assert_select "article[aria-label='No jobs have run yet']"
    assert_select "article[aria-label='Job tag not configured']", count: 0
  end

  test "show renders preload instructions when the module is not preloaded" do
    PgPeek::PgStatStatements.stub(:new, not_preloaded_stat_statements) do
      get pg_peek.database_job_path(@database, "PostPublishJob")
    end

    assert_response :success
    assert_select "article[aria-label='Extension pg_stat_statements is not preloaded']"
  end

  test "index shows a namespaced job by its class name and links to its page" do
    skip_unless_usable(@pg_stat_statements)
    Reports::PostSummaryJob.perform_now

    get pg_peek.database_jobs_path(@database)

    assert_response :success
    assert_select "a[href='/pg_peek/databases/primary/jobs/Reports::PostSummaryJob']",
                  text: "Reports::PostSummaryJob"
  end

  test "index shows a job name with its namespace dimmed and the full name on hover" do
    skip_unless_usable(@pg_stat_statements)
    Reports::PostSummaryJob.perform_now

    get pg_peek.database_jobs_path(@database)

    assert_response :success
    assert_select "td.name-column .qualified[title='Reports::PostSummaryJob']" do
      assert_select ".namespace", text: "Reports::"
      assert_select ".leaf", text: "PostSummaryJob"
    end
  end

  test "show titles a namespaced job by its class name and lists its queries" do
    skip_unless_usable(@pg_stat_statements)
    Reports::PostSummaryJob.perform_now

    get pg_peek.database_job_path(@database, "Reports::PostSummaryJob")

    assert_response :success
    assert_select "h1 code.name", text: "Reports::PostSummaryJob"
    assert_select "article[aria-label='No queries found']", count: 0
    assert_select "td", text: /length\(title\)/
  end

  private

  def not_preloaded_stat_statements
    PgPeek::PgStatStatements.new(database: @database).tap do |pg_stat|
      pg_stat.define_singleton_method(:preloaded?) { false }
      pg_stat.define_singleton_method(:shared_preload_libraries) { "" }
    end
  end

  # Statistics outlive a test run, so jobs run by other tests stay in them.
  def no_jobs_stat_statements
    PgPeek::PgStatStatements.new(database: @database).tap do |pg_stat|
      pg_stat.define_singleton_method(:jobs) { [] }
    end
  end

  def with_query_log_tags(tags)
    config = Rails.application.config.active_record
    original = config.query_log_tags
    config.query_log_tags = tags
    yield
  ensure
    config.query_log_tags = original
  end
end
