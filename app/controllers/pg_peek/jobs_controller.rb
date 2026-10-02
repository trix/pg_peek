class PgPeek::JobsController < PgPeek::ApplicationController
  before_action :set_database
  before_action :require_sqlcommenter_tags

  def index
    return render "pg_peek/pg_stat_statements/not_preloaded" unless @pg_stat_statements.usable?

    # Without the job tag no query can be attributed to a job, so an empty
    # dashboard has nothing to do with whether jobs have run.
    @job_tag_configured = query_log_tags.include?(:job)
    @stats_reset_at = @pg_stat_statements.reset_at
    @report = PgPeek::Reports::Jobs.new(database: @database)
  end

  def show
    @job_class = params[:job_class]
    return render "pg_peek/pg_stat_statements/not_preloaded" unless @pg_stat_statements.usable?

    @report = PgPeek::Reports::JobQueries.new(database: @database, job_class: @job_class)
  end

  private
    def set_database
      @database = PgPeek::Database.find(params[:database_id]) or
        raise ActiveRecord::RecordNotFound, "Database not found"
      @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)
    end

    def query_log_tags
      Rails.application.config.active_record.query_log_tags.to_a
    end

    def require_sqlcommenter_tags
      config = Rails.application.config.active_record

      unless config.query_log_tags_enabled
        return render plain: "Query log tags are not enabled. Please enable config.active_record.query_log_tags_enabled in your Rails configuration.", status: :unprocessable_entity
      end

      if config.query_log_tags_format == :legacy
        render plain: "Legacy query log tags format is not supported. Please set config.active_record.query_log_tags_format to :sqlcommenter in your Rails configuration.", status: :unprocessable_entity
      end
    end
end
