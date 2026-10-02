# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [ File.expand_path("../test/dummy/db/migrate", __dir__) ]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [ File.expand_path("fixtures", __dir__) ]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"
  ActiveSupport::TestCase.fixtures :all
end

class ActiveSupport::TestCase
  # Activity tests need sessions that are not this one. They are opened with
  # the pg gem directly so ActiveRecord's pool never sees them, and closed
  # after each test. A query sent with send_query runs while the test goes on.
  def open_pg_session
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    conn = PG.connect(host: config[:host], port: config[:port], dbname: config[:database],
                      user: config[:username], password: config[:password])
    (@extra_sessions ||= []) << conn
    conn
  end

  teardown do
    (@extra_sessions || []).each do |conn|
      conn.cancel if conn.respond_to?(:cancel)
      conn.discard_results
      conn.close
    rescue PG::Error
      nil
    end
  end

  # pg_stat_activity is a snapshot taken once per transaction, and a test is
  # one transaction: clear it before each look or the new session never
  # appears, however long you wait.
  def wait_for(what, timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      ActiveRecord::Base.connection.execute("SELECT pg_stat_clear_snapshot()")
      return if yield
      flunk "timed out waiting for #{what}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.05
    end
  end

  # The role dokku-review-pg and managed hosts hand an app: a plain CREATE USER,
  # without pg_read_all_settings, pg_read_all_stats or EXECUTE on
  # pg_stat_statements_reset. The transactional test rolls the role and the
  # SET LOCAL back afterwards.
  def become_unprivileged_role(database)
    database.connection.execute("CREATE ROLE peek_unprivileged NOLOGIN")
    database.connection.execute("SET LOCAL ROLE peek_unprivileged")
  end

  # Tagged the way Rails' query_log_tags writes them.
  def sleeping_query(seconds = 30, controller: "posts", action: "index")
    "SELECT pg_sleep(#{seconds}) /*action='#{action}',application='Dummy',controller='#{controller}'*/"
  end

  # The dummy schemas already create the extension; this is the safety net for
  # a test that dropped it and did not put it back.
  def install_pg_stat_statements(database)
    database.connection.execute("CREATE EXTENSION IF NOT EXISTS pg_stat_statements")
  rescue ActiveRecord::StatementInvalid
    # Not available on this server: tests that need it skip via skip_unless_usable.
  end

  # A development machine may run PostgreSQL without the module preloaded, so
  # skipping is the right answer there. In CI it means the workflow regressed and
  # this coverage disappeared silently -- which is how queries that were broken on
  # PostgreSQL 14-16 survived a green five-version matrix.
  def skip_unless_usable(pg_stat_statements)
    return if pg_stat_statements.usable?

    message = "pg_stat_statements not usable on this server"

    if ENV["CI"].present?
      flunk "#{message} -- CI must start PostgreSQL with shared_preload_libraries=pg_stat_statements"
    end

    skip message
  end
end
