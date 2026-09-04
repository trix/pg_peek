class PgPeek::ApplicationController < ActionController::Base
  layout "pg_peek/application"

  before_action :authenticate

  private
    # Resolved per request rather than when this class is loaded, so credentials
    # set after boot are honoured instead of silently ignored.
    #
    # Credentials win over the local exemption: a tunnelled development server
    # is reachable, and setting them is how you protect it.
    def authenticate
      return if PgPeek.config.public_dashboard
      return request_http_basic_credentials if PgPeek.config.credentials?
      return if Rails.env.local?

      render template: "pg_peek/authentication_required", status: :forbidden
    end

    def request_http_basic_credentials
      authenticate_or_request_with_http_basic("PgPeek") do |username, password|
        # & rather than && so both comparisons always run.
        ActiveSupport::SecurityUtils.secure_compare(username, PgPeek.config.username) &
          ActiveSupport::SecurityUtils.secure_compare(password, PgPeek.config.password)
      end
    end
end
