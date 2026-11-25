require "test_helper"

# The dummy declares primary_replica with replica: true, over the same database
# as primary.
class ReplicaMarkerTest < ActionDispatch::IntegrationTest
  setup do
    @primary = PgPeek::Database.find("primary")
    @replica = PgPeek::Database.find("primary_replica")
  end

  test "a primary carries no marker" do
    get pg_peek.database_path(@primary)

    assert_response :success
    assert_select ".replica", count: 0
  end

  test "the overview names a replica first among its vitals" do
    get pg_peek.database_path(@replica)

    assert_response :success
    assert_select "p.vitals span:first-child.replica", text: "replica"
  end

  test "the navigation does not repeat it" do
    get pg_peek.database_path(@replica)

    assert_select "nav .replica", count: 0
  end

  test "the indexes page says a replica's scan counts are its own" do
    get pg_peek.database_indexes_path(@primary)
    assert_select "[data-replica-note]", count: 0

    get pg_peek.database_indexes_path(@replica)
    assert_select "[data-replica-note]", text: /may be in use on the primary/
  end

  test "the list of databases gives a replica its role" do
    get pg_peek.databases_path

    assert_select "tr", text: /primary_replica\s+replica/
  end

  test "the overview no longer dumps the database's configuration" do
    get pg_peek.database_path(@primary)

    assert_select "summary", text: "database details", count: 0
    assert_select "summary", text: "installed extensions"
  end
end
