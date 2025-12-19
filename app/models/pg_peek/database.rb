class PgPeek::Database
  attr_reader :name, :primary, :replica, :schema_format

  def self.all
    ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).select do |db_config|
      db_config.adapter == "postgresql"
    end.map do |db_config|
      PgPeek::Database.new(
        name: db_config.name,
        primary: db_config.primary?,
        replica: db_config.replica?,
        schema_format: db_config.schema_format
      )
    end
  end

  def self.find(name)
    all.find { |db| db.name == name }
  end

  def initialize(name:, primary: false, replica: false, schema_format:)
    @name = name
    @primary = primary
    @replica = replica
    @schema_format = schema_format
  end

  def to_param
    @name
  end

  def connection
    case name
    when "primary"
      ApplicationRecord.connection
    when "tracking"
      Tracking::ApplicationRecord.connection
    end
  end

  def version
    @version ||= connection.execute("SELECT version()").first["version"]
  end

  def installed_extensions
    connection.execute("SELECT name, default_version, installed_version FROM pg_available_extensions WHERE installed_version IS NOT NULL ORDER BY name").to_a
  end

  def tables
    connection.tables.sort - %w[schema_migrations ar_internal_metadata]
  end
end
