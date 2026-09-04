
# https://docs.percona.com/pg-stat-monitor/comparison.html
class PgPeek::PgStatStatementsController < PgPeek::ApplicationController
  def outliers
    @query_log_tags_enabled = Rails.application.config.active_record.query_log_tags_enabled
    @query_log_tags_format = Rails.application.config.active_record.query_log_tags_format
    @query_log_tags = Rails.application.config.active_record.query_log_tags
    @query_log_tags_prepend_comment = Rails.application.config.active_record.query_log_tags_prepend_comment

    # check if config.active_record.query_log_tags_enabled is true
    unless @query_log_tags_enabled
      return render plain: "Query log tags are not enabled. Please enable config.active_record.query_log_tags_enabled in your Rails configuration.", status: :unprocessable_entity
    end

    # https://guides.rubyonrails.org/configuring.html#config-active-record-query-log-tags-format
    if Rails.application.config.active_record.query_log_tags_format == :legacy
      return render plain: "Legacy query log tags format is not supported. Please set config.active_record.query_log_tags_format to :sqlcommenter in your Rails configuration.", status: :unprocessable_entity
    end

    @database = PgPeek::Database.find(params[:database_id])
    @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)

    # The extension can be installed while the module was never preloaded, in
    # which case querying its views raises instead of returning rows.
    return render :not_preloaded unless @pg_stat_statements.usable?

    @outliers = @pg_stat_statements.outliers
  end

  def reset
    @database = PgPeek::Database.find(params[:database_id])
    PgPeek::PgStatStatements.new(database: @database).reset!

    redirect_to root_database_pg_stat_statements_path(@database), notice: "pg_stat_statements has been reset successfully."
  end
end
