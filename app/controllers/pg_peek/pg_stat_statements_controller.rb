
# https://docs.percona.com/pg-stat-monitor/comparison.html
class PgPeek::PgStatStatementsController < PgPeek::ApplicationController
  def index
    @query_log_tags_enabled = Rails.application.config.active_record.query_log_tags_enabled
    @query_log_tags_format = Rails.application.config.active_record.query_log_tags_format
    @query_log_tags = Rails.application.config.active_record.query_log_tags
    @query_log_tags_prepend_comment = Rails.application.config.active_record.query_log_tags_prepend_comment

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

    @database = PgPeek::Database.find(params[:database_id])
    @pg_stat_statements = PgPeek::PgStatStatements.new(connection: @database.connection)

    # Group routes by controller and list unique actions per controller
    routes = Rails.application.routes.routes

    @controllers_actions = routes.group_by { |route| route.defaults[:controller] }.transform_values do |routes|
      routes.map { |route| route.defaults[:action] }.compact_blank.sort.uniq
    end.compact_blank

    # Filter out internal Rails controllers (optional but common)
    @controllers_actions.reject! { |controller, _| controller&.start_with?("rails/", "action_", "active_storage", "turbo", "view_components") }

    @application = Rails.application.class.module_parent_name

    @outliers = @pg_stat_statements.outliers
  end

  def destroy
    @database = PgPeek::Database.find(params[:database_id])
    PgPeek::PgStatStatements.new(connection: @database.connection).reset!

    redirect_to pg_stat_statements_path, notice: "pg_stat_statements has been reset successfully."
  end
end
