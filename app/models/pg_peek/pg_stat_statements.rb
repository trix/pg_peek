# https://gist.github.com/defkode/63ac230e4175f7c46db92e6fad0a1d09

class PgPeek::PgStatStatements
  attr_reader :connection, :default_version, :installed_version

  def initialize(connection:)
    @connection = connection

    verify_installation
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

    result = connection.execute <<-SQL
    SELECT interval '1 millisecond' * total_exec_time AS total_exec_time,
    to_char((total_exec_time/sum(total_exec_time) OVER()) * 100, 'FM90D0') || '%%'  AS prop_exec_time,
    to_char(calls, 'FM999G999G999G990') AS ncalls,
    ROUND(total_exec_time/calls) AS avg_exec_ms,
    interval '1 millisecond' * (shared_blk_read_time + shared_blk_write_time) AS sync_io_time,
    query AS query
    FROM pg_stat_statements WHERE userid = (SELECT usesysid FROM pg_user WHERE usename = current_user LIMIT 1)
    ORDER BY total_exec_time DESC
    LIMIT 20;
    SQL

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
