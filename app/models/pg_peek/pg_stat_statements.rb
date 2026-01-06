class PgPeek::PgStatStatements
  attr_reader :database, :default_version, :installed_version

  def initialize(database:)
    @database = database

    verify_installation
  end

  def connection
    database.connection
  end

  def available?
    default_version.present?
  end

  def installed?
    installed_version.present?
  end

  def install!
    return if installed?

    connection.execute <<-SQL
      CREATE EXTENSION pg_stat_statements;
    SQL

    verify_installation
  end

  def upgrade!
    return unless installed?

    connection.execute <<-SQL
      ALTER EXTENSION pg_stat_statements UPDATE TO '#{default_version}';
    SQL

    verify_installation
  end

  def outdated?
    return false unless installed?

    @installed_version != @default_version
  end

  def reset!
    return unless installed?

    connection.execute <<-SQL
      SELECT pg_stat_statements_reset();
    SQL
  end

  def reset_at
    return unless installed?

    result = ActiveRecord::Base.connection.execute <<-SQL
      SELECT stats_reset FROM pg_stat_statements_info;
    SQL

    result.first["stats_reset"]
  end

  def outliers
    return unless installed?

    query = PgPeek::QueryLoader.load("pg_stat_statements/outliers",
                                      pg_version: database.major_version,
                                      limit: PgPeek.config.outliers_limit)
    result = connection.execute(query)
    result.to_a
  end

  def jobs
    return unless installed?

    query = PgPeek::QueryLoader.load("pg_stat_statements/jobs",
                                      pg_version: database.major_version)
    result = connection.execute(query)
    result.to_a
  end

  def outliers_by_job(job_class)
    return unless installed?

    # Build pattern to match job='JobClassName' in SQLcommenter
    # Need to escape for SQL LIKE and quote properly
    escaped_job = job_class.gsub("'", "''")
    pattern = "%job='#{escaped_job}'%"

    query = PgPeek::QueryLoader.load("pg_stat_statements/outliers_by_job",
                                      pg_version: database.major_version,
                                      job_pattern: connection.quote(pattern),
                                      limit: PgPeek.config.outliers_limit)
    result = connection.execute(query)
    result.to_a
  end

  private

  def verify_installation
    result = connection.execute <<-SQL
      SELECT default_version, installed_version FROM pg_available_extensions WHERE name = 'pg_stat_statements';
    SQL

    if result.any?
      @default_version = result.first["default_version"]
      @installed_version = result.first["installed_version"]
    end
  end
end
