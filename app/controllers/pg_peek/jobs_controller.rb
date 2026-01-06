class PgPeek::JobsController < PgPeek::ApplicationController
  def index
    @query_log_tags_enabled = Rails.application.config.active_record.query_log_tags_enabled
    @query_log_tags = Rails.application.config.active_record.query_log_tags

    unless @query_log_tags_enabled
      render plain: "Query log tags are not enabled. Please enable config.active_record.query_log_tags_enabled in your Rails configuration.", status: :unprocessable_entity
      return
    end

    if Rails.application.config.active_record.query_log_tags_format == :legacy
      render plain: "Legacy query log tags format is not supported. Please set config.active_record.query_log_tags_format to :sqlcommenter in your Rails configuration.", status: :unprocessable_entity
      return
    end

    @jobs = {}

    PgPeek::Database.all.each do |database|
      next unless database.connection_configured?

      pg_stat = PgPeek::PgStatStatements.new(database: database)
      next unless pg_stat.installed?

      pg_stat.jobs&.each do |row|
        job_class = row["job_class"]
        next unless job_class.present?

        @jobs[job_class] ||= { total_calls: 0, total_time_ms: 0, query_count: 0 }
        @jobs[job_class][:total_calls] += row["total_calls"].to_i
        @jobs[job_class][:total_time_ms] += row["total_exec_time_ms"].to_f
        @jobs[job_class][:query_count] += row["query_count"].to_i
      end
    end

    @jobs = @jobs.sort_by { |_, v| -v[:total_time_ms] }.to_h
  end

  def show
    @job_class = CGI.unescape(params[:job_class])
    @outliers_by_db = {}

    PgPeek::Database.all.each do |database|
      next unless database.connection_configured?

      pg_stat = PgPeek::PgStatStatements.new(database: database)
      next unless pg_stat.installed?

      outliers = pg_stat.outliers_by_job(@job_class)
      @outliers_by_db[database] = outliers if outliers&.any?
    end
  end
end
