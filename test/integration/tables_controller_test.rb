require "test_helper"

class TablesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @database = PgPeek::Database.find("primary")
  end

  test "index lists every table, each linking to its page" do
    get pg_peek.database_tables_path(@database)

    assert_response :success
    assert_select "h1", text: "tables"
    assert_select "input[data-filter-input][data-filter-noun=table]"
    assert_select "a[href='#{pg_peek.database_table_path(@database, "posts")}']", text: "posts"
  end

  test "show renders table detail page for existing table" do
    get pg_peek.database_table_path(@database, "posts")

    assert_response :success
    assert_select "h1", text: "posts"
    assert_select "a[href='#{pg_peek.database_tables_path(@database)}']", text: /tables/
  end

  test "show displays cache performance section" do
    get pg_peek.database_table_path(@database, "posts")

    assert_response :success
    assert_select "h2", text: "cache performance"
    assert_select "th", text: "heap cache hit"
    assert_select "th", text: "index cache hit"
    assert_select "th", text: "toast cache hit"
    assert_select "th", text: "toast index cache hit"
  end

  test "show displays row activity section" do
    get pg_peek.database_table_path(@database, "posts")

    assert_response :success
    assert_select "h2", text: "row activity"
    assert_select "th", text: "estimated rows"
    assert_select "th", text: "sequential scans"
    assert_select "th", text: "index scans"
    assert_select "th", text: "live tuples"
    assert_select "th", text: "dead tuples"
  end

  test "show displays maintenance section" do
    get pg_peek.database_table_path(@database, "posts")

    assert_response :success
    assert_select "h2", text: "maintenance"
    assert_select "th", text: "last vacuum"
    assert_select "th", text: "last autovacuum"
    assert_select "th", text: "last analyze"
    assert_select "th", text: "last autoanalyze"
  end

  test "show returns 404 for non-existent table" do
    get pg_peek.database_table_path(@database, "nonexistent_table_xyz")
    assert_response :not_found
  end

  test "show returns 404 for non-existent database" do
    get pg_peek.database_table_path("nonexistent_db", "posts")
    assert_response :not_found
  end
end
