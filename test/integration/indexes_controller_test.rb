require "test_helper"

class IndexesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @database = PgPeek::Database.find("primary")
  end

  test "index lists the database's indexes" do
    get pg_peek.database_indexes_path(@database)

    assert_response :success
    assert_select "h1", text: "indexes"
    assert_select "td", text: "posts_pkey"
  end

  test "index calls out unused indexes with their cost" do
    @database.connection.execute("CREATE INDEX index_posts_on_body_for_test ON posts (body)")

    get pg_peek.database_indexes_path(@database)

    # Other never-scanned indexes may already exist, so the count is not asserted.
    assert_select "article[aria-label='Unused indexes'] header", text: /never scanned/
    assert_select "tr", text: /index_posts_on_body_for_test.*unused/m
  end

  test "index needs no pg_stat_statements" do
    not_preloaded = PgPeek::PgStatStatements.new(database: @database)
    not_preloaded.define_singleton_method(:preloaded?) { false }

    PgPeek::PgStatStatements.stub(:new, not_preloaded) do
      get pg_peek.database_indexes_path(@database)
    end

    assert_response :success
    assert_select "td", text: "posts_pkey"
  end
end
