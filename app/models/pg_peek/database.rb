class PgPeek::Database
  attr_reader :name, :primary, :replica, :schema_format

  def self.available_postgres_databases
    ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).select do |db_config|
      db_config.adapter == "postgresql"
    end
  end

  def self.all
    available_postgres_databases.map do |db_config|
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
    connection_class = PgPeek.config.connection_class_for(name)
    connection_class&.connection
  end

  def connection_configured?
    connection.present?
  end

  def version_full
    @version_full ||= connection.execute("SELECT version()").first["version"]
  end

  def version
    @version ||= version_full.match(/PostgreSQL ([\d.]+)/)[1]
  end

  def major_version
    @major_version ||= version.split(".").first.to_i
  end

  def installed_extensions
    connection.execute("SELECT name, default_version, installed_version FROM pg_available_extensions WHERE installed_version IS NOT NULL ORDER BY name").to_a
  end

  def vitals
    @vitals ||= begin
      query = PgPeek::QueryLoader.load("database/vitals", pg_version: major_version)
      connection.execute(query).first || {}
    end
  end

  def tables_with_dead_tuples(threshold)
    query = PgPeek::QueryLoader.load("tables/dead_tuples", pg_version: major_version, threshold: threshold.to_i)
    connection.execute(query).to_a
  end

  def tables
    connection.tables.sort - PgPeek.config.excluded_tables
  end

  def table_exists?(table_name)
    connection.tables.include?(table_name)
  end

  def find_table(name)
    return nil unless table_exists?(name)
    PgPeek::Table.new(self, name)
  end
end
