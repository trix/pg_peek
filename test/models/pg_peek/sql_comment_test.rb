require "test_helper"

class PgPeek::SqlCommentTest < ActiveSupport::TestCase
  test "tags parses a trailing SQLcommenter comment into a hash" do
    query = "SELECT 1 /*action='index',application='Dummy',controller='posts'*/"

    assert_equal(
      { "action" => "index", "application" => "Dummy", "controller" => "posts" },
      PgPeek::SqlComment.tags(query)
    )
  end

  test "tags unescapes url-encoded values" do
    query = "SELECT 1 /*namespaced_controller='staff%2Fprocesses%2Fprocesses'*/"

    assert_equal "staff/processes/processes", PgPeek::SqlComment.tags(query)["namespaced_controller"]
  end

  test "tags returns an empty hash when there is no comment" do
    assert_equal({}, PgPeek::SqlComment.tags("SELECT 1"))
  end

  test "tags returns an empty hash for nil" do
    assert_equal({}, PgPeek::SqlComment.tags(nil))
  end

  test "label prefers the job tag over controller and action" do
    tags = { "job" => "PostAnalyticsJob", "controller" => "posts", "action" => "index" }

    assert_equal "PostAnalyticsJob", PgPeek::SqlComment.label(tags)
  end

  test "label joins controller and action" do
    assert_equal "posts#index", PgPeek::SqlComment.label({ "controller" => "posts", "action" => "index" })
  end

  test "label prefers namespaced_controller over controller" do
    tags = { "controller" => "processes", "namespaced_controller" => "staff/processes", "action" => "show" }

    assert_equal "staff/processes#show", PgPeek::SqlComment.label(tags)
  end

  test "label falls back to just the controller when there is no action" do
    assert_equal "posts", PgPeek::SqlComment.label({ "controller" => "posts" })
  end

  test "label returns nil when there is nothing to identify the source" do
    assert_nil PgPeek::SqlComment.label({})
    assert_nil PgPeek::SqlComment.label({ "application" => "Dummy" })
  end
end
