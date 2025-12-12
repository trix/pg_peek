class PgPeek::PgStatStatementsController < PgPeek::ApplicationController
  def index
    @query_log_tags_enabled = Rails.application.config.active_record.query_log_tags_enabled
    @query_log_tags_format = Rails.application.config.active_record.query_log_tags_format
    @query_log_tags = Rails.application.config.active_record.query_log_tags

    @pg_stat_statements_reset_at = pg_stat_statements_reset_at

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

    # if query_logs_tags_enabled
    #   app.config.active_record.query_log_tags |= [:controller] unless app.config.active_record.query_log_tags.include?(:namespaced_controller)
    #   app.config.active_record.query_log_tags |= [:action]

    #   ActiveSupport.on_load(:active_record) do
    #     ActiveRecord::QueryLogs.taggings = ActiveRecord::QueryLogs.taggings.merge(
    #       controller:            ->(context) { context[:controller]&.controller_name },
    #       action:                ->(context) { context[:controller]&.action_name },
    #       namespaced_controller: ->(context) {
    #         if context[:controller]
    #           controller_class = context[:controller].class
    #           # based on ActionController::Metal#controller_name, but does not demodulize
    #           unless controller_class.anonymous?
    #             controller_class.name.delete_suffix("Controller").underscore
    #           end
    #         end
    #       }
    #     )
    #   end

    @application = Rails.application.class.module_parent_name
    @action = "index"
    @namespaced_controller = ERB::Util.url_encode("delivery/api/v1/orders") # delivery%2Fapi%2Fv1%2Forders
  end

  def reset
    ActiveRecord::Base.connection.execute("SELECT pg_stat_statements_reset()")
    redirect_to pg_stat_statements_path, notice: "pg_stat_statements has been reset successfully."
  end

  private

  def pg_stat_statements_reset_at
    ActiveRecord::Base.connection.execute(
      "SELECT stats_reset FROM pg_stat_statements_info"
    ).first["stats_reset"]
  end
end
