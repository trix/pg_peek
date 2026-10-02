class PgPeek::PgStatStatements
  LIBRARY_NAME = "pg_stat_statements".freeze

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

  # The extension can be created in the database while the module itself was
  # never loaded at server start. Querying the view then raises
  # PG::ObjectNotInPrerequisiteState, so every read has to check this first.
  #
  # Roles without pg_read_all_settings (dokku's postgres plugin, most managed
  # hosts) cannot read shared_preload_libraries, so then the only way to tell
  # is to ask the module itself.
  def preloaded?
    if shared_preload_libraries
      shared_preload_libraries.split(",").map(&:strip).include?(LIBRARY_NAME)
    else
      installed? && module_loaded?
    end
  end

  def usable?
    installed? && preloaded?
  end

  # nil when this role may not examine the setting, as opposed to "" when
  # nothing is preloaded.
  def shared_preload_libraries
    return @shared_preload_libraries if defined?(@shared_preload_libraries)

    @shared_preload_libraries = without_aborting_transaction do
      connection.select_value(PgPeek::QueryLoader.mark("SHOW shared_preload_libraries")).to_s
    end
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.cause.is_a?(PG::InsufficientPrivilege)

    @shared_preload_libraries = nil
  end

  def outdated?
    return false unless installed?

    @installed_version != @default_version
  end

  # The extension revokes EXECUTE on the reset from PUBLIC, so only superusers
  # and roles granted it may run one.
  def resettable?
    return @resettable if defined?(@resettable)

    @resettable = usable? && connection.select_value(PgPeek::QueryLoader.mark(<<~SQL)) == true
      SELECT bool_and(has_function_privilege(oid, 'EXECUTE'))
      FROM pg_proc WHERE proname = 'pg_stat_statements_reset'
    SQL
  end

  # Server-wide on purpose. pg_stat_statements_info keeps a single stats_reset
  # for the whole server and only moves it when every entry is removed, so a
  # reset scoped to this database would leave "stats since" pointing at the
  # old time.
  def reset!
    return unless resettable?

    connection.execute PgPeek::QueryLoader.mark(<<-SQL)
      SELECT pg_stat_statements_reset();
    SQL
  end

  def reset_at
    return unless usable?

    value = connection.select_value PgPeek::QueryLoader.mark(<<-SQL)
      SELECT stats_reset FROM pg_stat_statements_info;
    SQL

    Time.zone.parse(value.to_s) if value.present?
  end

  def outliers
    return unless usable?

    query = PgPeek::QueryLoader.load("pg_stat_statements/outliers",
                                      pg_version: database.major_version,
                                      limit: PgPeek.config.outliers_limit)
    result = connection.execute(query)
    result.to_a
  end

  def statement_count
    return unless usable?

    connection.select_value(PgPeek::QueryLoader.mark(<<~SQL)).to_i
      SELECT count(*) FROM pg_stat_statements
      WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
    SQL
  end

  def endpoints
    return unless usable?

    query = PgPeek::QueryLoader.load("pg_stat_statements/endpoints",
                                      pg_version: database.major_version,
                                      limit: PgPeek.config.outliers_limit)
    connection.execute(query).to_a
  end

  def jobs
    return unless usable?

    query = PgPeek::QueryLoader.load("pg_stat_statements/jobs",
                                      pg_version: database.major_version)
    result = connection.execute(query)
    result.to_a
  end

  def outliers_by_job(job_class)
    return unless usable?

    # Rails writes the job tag url-encoded (job='Reports%3A%3ADigestJob'), so
    # match it encoded, with the % of the encoding escaped for LIKE.
    encoded_job = ActiveRecord::Base.sanitize_sql_like(ERB::Util.url_encode(job_class))
    pattern = "%job='#{encoded_job}'%"

    query = PgPeek::QueryLoader.load("pg_stat_statements/outliers_by_job",
                                      pg_version: database.major_version,
                                      job_pattern: connection.quote(pattern),
                                      limit: PgPeek.config.outliers_limit)
    result = connection.execute(query)
    result.to_a
  end

  private

  # pg_stat_statements_info() raises PG::ObjectNotInPrerequisiteState unless
  # the module was loaded at server start, and is readable by any role.
  def module_loaded?
    return @module_loaded if defined?(@module_loaded)

    @module_loaded = without_aborting_transaction do
      connection.select_value(PgPeek::QueryLoader.mark("SELECT 1 FROM pg_stat_statements_info"))
      true
    end
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.cause.is_a?(PG::ObjectNotInPrerequisiteState)

    @module_loaded = false
  end

  # A failed statement inside an open transaction (a host app's, or a
  # transactional test) would poison it; a savepoint confines the failure.
  def without_aborting_transaction(&)
    connection.transaction(requires_new: true, &)
  end

  def verify_installation
    result = connection.execute PgPeek::QueryLoader.mark(<<-SQL)
      SELECT default_version, installed_version FROM pg_available_extensions WHERE name = 'pg_stat_statements';
    SQL

    if result.any?
      @default_version = result.first["default_version"]
      @installed_version = result.first["installed_version"]
    end
  end
end
