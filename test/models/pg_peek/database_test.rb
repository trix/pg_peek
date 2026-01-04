require "test_helper"

class PgPeek::DatabaseTest < ActiveSupport::TestCase
  setup do
    @database = PgPeek::Database.find("primary")
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
end
