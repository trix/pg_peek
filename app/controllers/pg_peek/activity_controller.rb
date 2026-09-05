# What is happening right now, as opposed to what has been expensive since the
# last reset. Needs no pg_stat_statements, so it works on any install.
class PgPeek::ActivityController < PgPeek::ApplicationController
  REFRESH_INTERVALS = [ 5, 15, 60 ].freeze

  def show
    @database = PgPeek::Database.find(params[:database_id]) or raise ActiveRecord::RecordNotFound, "Database not found"
    @sessions = PgPeek::Reports::Sessions.new(database: @database)
    @blocked = PgPeek::Reports::Blocked.new(database: @database, sessions: @sessions)
    @summary = @database.connection_summary
    @captured_at = Time.zone.now
    # Only the offered intervals are honoured: a URL cannot make the page hammer the server.
    @refresh = REFRESH_INTERVALS.find { |seconds| seconds == params[:refresh].to_i }
    @show_idle = params[:idle].present?
  end
end
