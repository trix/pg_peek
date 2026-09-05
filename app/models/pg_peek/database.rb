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

  # The other configured databases on the same server, judged by host and
  # port. Production tends to give each database its own server; review apps
  # put them all on one, where a server-wide action such as a
  # pg_stat_statements reset reaches every one of them.
  def server_peers
    self.class.all.reject { |other| other.name == name }.select { |other| other.server == server }
  end

  def server
    config = self.class.available_postgres_databases.find { |db_config| db_config.name == name }
    return unless config

    [ config.host.presence || "localhost", config.configuration_hash[:port].presence || 5432 ].map(&:to_s)
  end

  def connection
    connection_class = PgPeek.config.connection_class_for(name)
    connection_class&.connection
  end

  # Cheap enough for the layout to ask on every request: reads the config, does
  # not resolve the class or check out a connection.
  def configured?
    PgPeek.config.connections.key?(name)
  end

  def connection_configured?
    connection.present?
  end

  def version_full
    @version_full ||= connection.execute(PgPeek::QueryLoader.mark("SELECT version()")).first["version"]
  end

  def version
    @version ||= version_full.match(/PostgreSQL ([\d.]+)/)[1]
  end

  def major_version
    @major_version ||= version.split(".").first.to_i
  end

  def installed_extensions
    connection.execute(PgPeek::QueryLoader.mark("SELECT name, default_version, installed_version FROM pg_available_extensions WHERE installed_version IS NOT NULL ORDER BY name")).to_a
  end

  def vitals
    @vitals ||= begin
      query = PgPeek::QueryLoader.load("database/vitals", pg_version: major_version)
      connection.execute(query).first || {}
    end
  end

  def indexes
    query = PgPeek::QueryLoader.load("indexes/all", pg_version: major_version)
    connection.execute(query).to_a
  end

  def sessions
    query = PgPeek::QueryLoader.load("activity/sessions", pg_version: major_version)
    connection.execute(query).to_a
  end

  def waiting_locks
    query = PgPeek::QueryLoader.load("activity/waiting_locks", pg_version: major_version)
    connection.execute(query).to_a
  end

  def connection_summary
    query = PgPeek::QueryLoader.load("activity/summary", pg_version: major_version)
    connection.execute(query).first || {}
  end

  def stats_reset_at
    value = vitals["stats_reset"]
    Time.zone.parse(value.to_s) if value.present?
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
