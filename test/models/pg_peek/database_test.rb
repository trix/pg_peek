require "test_helper"

class PgPeek::DatabaseTest < ActiveSupport::TestCase
  setup do
    @database = PgPeek::Database.find("primary")
  end

  test "server_peers lists the other configured databases on the same host and port" do
    peers = @database.server_peers.map(&:name)

    assert_includes peers, "analytics"
    assert_not_includes peers, "primary"
  end

  test "version_full returns full PostgreSQL version string" do
    version_full = @database.version_full

    assert_kind_of String, version_full
    assert_match(/PostgreSQL \d+(\.\d+)?/, version_full)
  end

  test "version returns semver version number" do
    version = @database.version

    assert_kind_of String, version
    assert_match(/^\d+(\.\d+)?$/, version)
  end

  test "major_version returns integer" do
    major_version = @database.major_version

    assert_kind_of Integer, major_version
    assert major_version >= 14, "Expected PostgreSQL 14 or higher"
  end

  test "major_version extracts first part of version" do
    version = @database.version
    major_version = @database.major_version

    assert_equal version.split(".").first.to_i, major_version
  end

  test "installed_extensions returns array of extensions" do
    extensions = @database.installed_extensions

    assert_kind_of Array, extensions
    assert extensions.any?, "Expected at least one installed extension"

    extension = extensions.first
    assert extension.key?("name"), "Expected extension to have 'name' key"
    assert extension.key?("default_version"), "Expected extension to have 'default_version' key"
    assert extension.key?("installed_version"), "Expected extension to have 'installed_version' key"
  end

  test "installed_extensions includes plpgsql" do
    extensions = @database.installed_extensions
    extension_names = extensions.map { |e| e["name"] }

    assert_includes extension_names, "plpgsql"
  end

  test "tables returns sorted array of table names" do
    tables = @database.tables

    assert_kind_of Array, tables
    assert_equal tables, tables.sort
  end

  test "tables excludes configured tables" do
    tables = @database.tables

    PgPeek.config.excluded_tables.each do |excluded|
      assert_not_includes tables, excluded
    end
  end

  test "tables excludes schema_migrations and ar_internal_metadata by default" do
    tables = @database.tables

    assert_not_includes tables, "schema_migrations"
    assert_not_includes tables, "ar_internal_metadata"
  end

  # Dead tuples show up in the statistics only once committed, so the tables are
  # built in a session of their own and dropped afterwards. Autovacuum is off on
  # them so it cannot clean up before the test looks.
  test "tables_with_dead_tuples flags only tables past autovacuum's trigger point" do
    session = open_pg_session
    # 3 of 4 rows dead: a high share, but below autovacuum's trigger point of 50.
    session.exec("CREATE TABLE peek_dead_small (id int) WITH (autovacuum_enabled = false)")
    session.exec("INSERT INTO peek_dead_small SELECT generate_series(1, 4)")
    session.exec("DELETE FROM peek_dead_small WHERE id > 1")
    # 500 dead next to 500 live: past the trigger point of 50 + 0.2 * 500.
    session.exec("CREATE TABLE peek_dead_large (id int) WITH (autovacuum_enabled = false)")
    session.exec("INSERT INTO peek_dead_large SELECT generate_series(1, 1000)")
    session.exec("DELETE FROM peek_dead_large WHERE id > 500")

    flagged = []
    wait_for("the dead tuples to be counted") do
      # A session reports its counts between statements, at most about once a
      # second, so it has to keep running statements until they arrive.
      session.exec("SELECT 1")
      flagged = @database.tables_with_dead_tuples(PgPeek.config.dead_tuple_warning_threshold).map { |row| row["relname"] }
      flagged.include?("peek_dead_large")
    end

    assert_not_includes flagged, "peek_dead_small"
    assert PgPeek::Table.new(@database, "peek_dead_large").dead_tuple_warning?
    assert_not PgPeek::Table.new(@database, "peek_dead_small").dead_tuple_warning?
  ensure
    session&.exec("DROP TABLE IF EXISTS peek_dead_small, peek_dead_large")
  end
end
