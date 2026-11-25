class PgPeek::ApplicationController < ActionController::Base
  layout "pg_peek/application"

  # Host applications may set include_all_helpers = false, which limits a
  # controller to its own matching helper.
  helper PgPeek::ApplicationHelper, PgPeek::ReportHelper
  helper_method :switchable_databases

  before_action :authenticate
  around_action :in_english

  private
    # The interface is written in English, and so must be the words Rails
    # supplies for it. Under a host's own locale they come out mixed -- "stats
    # since 3 Tage ago", "4.002 statement" -- since the inflections that turn
    # "statement" into "statements" belong to a locale too.
    #
    # A host may have ruled English out of its available locales, and then
    # there is nothing better to switch to than what it already uses.
    def in_english(&)
      I18n.with_locale(I18n.locale_available?(:en) ? :en : I18n.locale, &)
    end

    def switchable_databases
      @switchable_databases ||= PgPeek::Database.all.select(&:configured?)
    end

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
