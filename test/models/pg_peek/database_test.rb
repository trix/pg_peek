require "test_helper"

class PgPeek::DatabaseTest < ActiveSupport::TestCase
  setup do
    @database = PgPeek::Database.find("primary")
  end

  test "version_full returns full PostgreSQL version string" do
    version_full = @database.version_full

    assert_kind_of String, version_full
    assert_match(/PostgreSQL \d+\.\d+/, version_full)
  end

  test "version returns semver version number" do
    version = @database.version

    assert_kind_of String, version
    assert_match(/^\d+\.\d+$/, version)
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
end
