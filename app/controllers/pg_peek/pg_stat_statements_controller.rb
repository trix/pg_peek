class PgPeek::PgStatStatementsController < PgPeek::ApplicationController
  def index
    @query_log_tags_enabled = Rails.application.config.active_record.query_log_tags_enabled
    @query_log_tags_format = Rails.application.config.active_record.query_log_tags_format
    @query_log_tags = Rails.application.config.active_record.query_log_tags

    @pg_stat_statements = PgPeek::PgStatStatements.new

    @pg_stat_statements_reset_at = @pg_stat_statements.reset_at
    @pg_stat_statements_installed_version = @pg_stat_statements.installed_version
    @pg_stat_statements_default_version = @pg_stat_statements.default_version

    # check if config.active_record.query_log_tags_enabled is true
    unless @query_log_tags_enabled
      render plain: "Query log tags are not enabled. Please enable config.active_record.query_log_tags_enabled in your Rails configuration.", status: :unprocessable_entity
      nil
    end

    # https://guides.rubyonrails.org/configuring.html#config-active-record-query-log-tags-format
    if Rails.application.config.active_record.query_log_tags_format == :legacy
      render plain: "Legacy query log tags format is not supported. Please set config.active_record.query_log_tags_format to :sqlcommenter in your Rails configuration.", status: :unprocessable_entity
      nil
    end

    @application = Rails.application.class.module_parent_name
    @action = "index"
    @namespaced_controller = ERB::Util.url_encode("delivery/api/v1/orders") # delivery%2Fapi%2Fv1%2Forders
  end

  def reset
    PgPeek::PgStatStatements.reset!

    redirect_to pg_stat_statements_path, notice: "pg_stat_statements has been reset successfully."
  end
end
