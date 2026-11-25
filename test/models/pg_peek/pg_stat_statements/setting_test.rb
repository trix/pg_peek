require "test_helper"

class PgPeek::PgStatStatements::SettingTest < ActiveSupport::TestCase
  test "reads the settings of the server with what is known of each" do
    database = PgPeek::Database.find("primary")
    install_pg_stat_statements(database)
    pg_stat_statements = PgPeek::PgStatStatements.new(database: database)
    skip_unless_usable(pg_stat_statements)

    settings = pg_stat_statements.setting_details

    assert_equal %w[max save track track_planning track_utility], settings.map(&:name)
    settings.each do |setting|
      assert setting.does.present?, "#{setting.name} is not explained"
      assert_includes PgPeek::PgStatStatements::Setting::CHANGES.values, setting.change
      # Every value the server allows is one this file has something to say about.
      assert setting.values.values.all?(&:present?), "#{setting.name}: #{setting.values.inspect}"
    end
    assert_equal settings.to_h { |setting| [ setting.name, setting.value ] }, pg_stat_statements.settings
  end

  test "a number has a range and no list of values" do
    setting = build("name" => "pg_stat_statements.max", "setting" => "5000", "vartype" => "integer",
                    "min_val" => "100", "max_val" => "1073741823", "boot_val" => "5000", "context" => "postmaster")

    assert_equal "max", setting.name
    assert_equal "pg_stat_statements.max", setting.full_name
    assert_equal %w[100 1073741823], setting.range
    assert_empty setting.values
    assert_equal "5000", setting.default
    assert_equal "needs a server restart", setting.change
  end

  test "an enum lists the values the server allows, in its order" do
    setting = build("name" => "pg_stat_statements.track", "setting" => "top", "vartype" => "enum",
                    "enumvals" => "{none,top,all}", "boot_val" => "top", "context" => "superuser")

    assert_equal %w[none top all], setting.values.keys
    assert_match(/counted twice/, setting.values["all"])
    assert_nil setting.range
  end

  test "a setting this version has not heard of falls back on the server's description" do
    setting = build("name" => "pg_stat_statements.track_something_new", "setting" => "on", "vartype" => "bool",
                    "boot_val" => "off", "context" => "superuser", "short_desc" => "Tracks something new.")

    assert_equal "Tracks something new.", setting.does
    assert_equal({ "on" => nil, "off" => nil }, setting.values)
  end

  private
    def build(row) = PgPeek::PgStatStatements::Setting.new(row)
end
