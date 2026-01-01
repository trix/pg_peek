require "test_helper"

class TablesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @database = PgPeek::Database.find("primary")
  end

  test "show renders table detail page for existing table" do
    get pg_peek.database_table_path(@database, "posts")

    assert_response :success
    assert_select "h1", text: /posts/
    assert_select "article[aria-label='Cache Performance']"
    assert_select "article[aria-label='Row Activity']"
    assert_select "article[aria-label='Maintenance']"
  end

  test "show displays breadcrumb navigation" do
    get pg_peek.database_table_path(@database, "posts")

    assert_response :success
    assert_select "nav[aria-label='Breadcrumb']" do
      assert_select "a", text: "Databases"
      assert_select "a", text: @database.name
      assert_select "strong", text: "posts"
    end
  end

  test "show displays cache performance section" do
    get pg_peek.database_table_path(@database, "posts")

    assert_response :success
    assert_select "article[aria-label='Cache Performance']" do
      assert_select "th", text: "Heap Cache Hit"
      assert_select "th", text: "Index Cache Hit"
      assert_select "th", text: "Toast Cache Hit"
      assert_select "th", text: "Toast Index Cache Hit"
    end
  end

  test "show displays row activity section" do
    get pg_peek.database_table_path(@database, "posts")

    assert_response :success
    assert_select "article[aria-label='Row Activity']" do
      assert_select "th", text: "Estimated Rows"
      assert_select "th", text: "Sequential Scans"
      assert_select "th", text: "Index Scans"
      assert_select "th", text: "Live Tuples"
      assert_select "th", text: "Dead Tuples"
    end
  end

  test "show displays maintenance section" do
    get pg_peek.database_table_path(@database, "posts")

    assert_response :success
    assert_select "article[aria-label='Maintenance']" do
      assert_select "th", text: "Last Vacuum"
      assert_select "th", text: "Last Autovacuum"
      assert_select "th", text: "Last Analyze"
      assert_select "th", text: "Last Autoanalyze"
    end
  end

  test "show includes link to filtered pg_stat_statements" do
    get pg_peek.database_table_path(@database, "posts")

    assert_response :success
    assert_select "a[href*='table=posts']", text: /View queries for this table/
  end

  test "show returns 404 for non-existent table" do
    get pg_peek.database_table_path(@database, "nonexistent_table_xyz")
    assert_response :not_found
  end

  test "show returns 404 for non-existent database" do
    get pg_peek.database_table_path("nonexistent_db", "posts")
    assert_response :not_found
  end

  test "database show page lists tables with inline stats" do
    get pg_peek.database_path(@database)

    assert_response :success
    assert_select "summary" do
      assert_select "a[href*='posts']"
      assert_select "small", text: /H:.*I:/
    end
  end

  test "database show page has chart icon links to table detail" do
    get pg_peek.database_path(@database)

    assert_response :success
    assert_select "a[href='#{pg_peek.database_table_path(@database, 'posts')}'] svg"
  end
end
