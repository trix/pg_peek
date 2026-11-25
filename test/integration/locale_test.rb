require "test_helper"

class LocaleTest < ActionDispatch::IntegrationTest
  GERMAN = {
    datetime: { distance_in_words: {
      less_than_x_minutes: { one: "weniger als eine Minute", other: "weniger als %{count} Minuten" },
      x_minutes: { one: "eine Minute", other: "%{count} Minuten" },
      about_x_hours: { one: "etwa eine Stunde", other: "etwa %{count} Stunden" },
      x_days: { one: "ein Tag", other: "%{count} Tage" }
    } },
    number: { format: { delimiter: ".", separator: ",", precision: 2 } }
  }.freeze

  setup do
    @database = PgPeek::Database.find("primary")
    I18n.backend.store_translations(:de, GERMAN)
    # The set of available locales is remembered from whenever it was first asked for.
    I18n.config.clear_available_locales_set
  end

  teardown do
    I18n.backend.reload!
    I18n.config.clear_available_locales_set
  end

  test "counted things are plural under a host's own locale" do
    install_pg_stat_statements(@database)
    skip_unless_usable(PgPeek::PgStatStatements.new(database: @database))

    in_german { get pg_peek.database_path(@database) }

    assert_response :success
    # The inflection that makes "statement" plural is English's, not German's.
    assert_select "p.vitals span", text: /\A[\d,]+ statements\z/
  end

  test "times are worded in English under a host's own locale" do
    in_german { get pg_peek.database_indexes_path(@database) }

    assert_response :success
    assert_select ".toolbar small", text: /scan counts since/
    assert_no_match(/Minuten?|Stunden?|Tage?\b/, response.body)
  end

  test "the host's locale is back in place after the request" do
    in_german do
      get pg_peek.database_path(@database)

      assert_equal :de, I18n.locale
    end
  end

  private
    def in_german(&)
      I18n.with_locale(:de, &)
    end
end
