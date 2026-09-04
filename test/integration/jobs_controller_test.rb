require "test_helper"
require "minitest/mock"

class JobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @database = PgPeek::Database.find("primary")
    @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)
    @pg_stat_statements.install! if @pg_stat_statements.available?
  end

  test "index renders when the extension is usable" do
    skip_unless_usable(@pg_stat_statements)

    get pg_peek.jobs_path

    assert_response :success
    assert_select "h1", text: "ActiveJob Dashboard"
    assert_select "article[aria-label='Extension pg_stat_statements is not preloaded']", count: 0
  end

  test "index renders preload instructions when the module is not preloaded" do
    PgPeek::PgStatStatements.stub(:new, not_preloaded_stat_statements) do
      get pg_peek.jobs_path
    end

    assert_response :success
    assert_select "article[aria-label='Extension pg_stat_statements is not preloaded']"
  end

  test "show renders preload instructions when the module is not preloaded" do
    PgPeek::PgStatStatements.stub(:new, not_preloaded_stat_statements) do
      get pg_peek.job_path("PostPublishJob")
    end

    assert_response :success
    assert_select "article[aria-label='Extension pg_stat_statements is not preloaded']"
  end

  private

  def not_preloaded_stat_statements
    PgPeek::PgStatStatements.new(database: @database).tap do |pg_stat|
      pg_stat.define_singleton_method(:preloaded?) { false }
      pg_stat.define_singleton_method(:shared_preload_libraries) { "" }
    end
  end
end
