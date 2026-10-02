require "test_helper"

class PgPeek::ApplicationHelperTest < ActionView::TestCase
  include PgPeek::Engine.routes.url_helpers
  include PgPeek::ApplicationHelper

  # format_rate tests
  test "format_rate returns N/A for nil seconds" do
    assert_equal "N/A", format_rate(100, nil)
  end

  test "format_rate returns N/A for zero seconds" do
    assert_equal "N/A", format_rate(100, 0)
  end

  test "format_rate returns N/A for nil count" do
    assert_equal "N/A", format_rate(nil, 3600)
  end

  test "format_rate returns per day for very low rates" do
    # 1 event per day = 1/86400 per second
    result = format_rate(1, 86400)
    assert_match(%r{/day\)$}, result)
  end

  test "format_rate returns per hour for moderate rates" do
    # 100 events per hour = ~0.028 per second
    result = format_rate(100, 3600)
    assert_match(%r{/hr\)$}, result)
  end

  test "format_rate returns per minute for higher rates" do
    # 60 events per minute = 1 per second
    result = format_rate(3600, 3600)
    assert_match(%r{/min\)$}, result)
  end

  test "format_rate returns per second for high rates" do
    # 360000 events per hour = 100 per second
    result = format_rate(360000, 3600)
    assert_match(%r{/s\)$}, result)
  end

  # format_count_with_rate tests
  test "format_count_with_rate returns N/A for nil count" do
    assert_equal "N/A", format_count_with_rate(nil, 3600)
  end

  test "format_count_with_rate includes count and rate" do
    result = format_count_with_rate(1000, 3600)
    assert_match(/^1,000/, result)
    assert_match(/\(~/, result)
  end

  test "format_count_with_rate returns just count when seconds is nil" do
    result = format_count_with_rate(1000, nil)
    assert_equal "1,000", result
  end

  # format_number tests
  test "format_number returns N/A for nil" do
    assert_equal "N/A", format_number(nil)
  end

  test "format_number adds thousands separators" do
    assert_equal "1,234,567", format_number(1234567)
  end

  test "format_number handles small numbers" do
    assert_equal "42", format_number(42)
  end

  # format_percentage tests
  test "format_percentage returns N/A for nil" do
    assert_equal "N/A", format_percentage(nil)
  end

  test "format_percentage adds percent sign" do
    assert_equal "95.5%", format_percentage(95.5)
  end

  test "format_percentage handles integer" do
    assert_equal "100%", format_percentage(100)
  end

  # format_time_ago tests
  test "format_time_ago returns Never for nil" do
    assert_equal "Never", format_time_ago(nil)
  end

  test "format_time_ago includes 'ago' suffix" do
    result = format_time_ago(1.hour.ago)
    assert_match(/ago$/, result)
  end

  # format_inline_cache_stats tests
  test "stats_since_link marks statistics under an hour old as provisional" do
    link = stats_since_link(PgPeek::Database.find("primary"), 10.minutes.ago)

    assert_includes link, 'class="provisional"'
    assert_includes link, 'title="figures may not be representative yet"'
  end

  test "stats_since_link leaves older statistics unmarked" do
    link = stats_since_link(PgPeek::Database.find("primary"), 2.hours.ago)

    assert_not_includes link, "provisional"
    assert_includes link, 'title="figures are cumulative since the last pg_stat_statements reset"'
  end

  test "format_inline_cache_stats shows both ratios" do
    result = format_inline_cache_stats(98.5, 95.2)
    assert_equal "H: 98.5% I: 95.2%", result
  end

  test "format_inline_cache_stats shows dash for nil heap ratio" do
    result = format_inline_cache_stats(nil, 95.2)
    assert_equal "H: - I: 95.2%", result
  end

  test "format_inline_cache_stats shows dash for nil index ratio" do
    result = format_inline_cache_stats(98.5, nil)
    assert_equal "H: 98.5% I: -", result
  end

  test "format_inline_cache_stats shows dashes for both nil" do
    result = format_inline_cache_stats(nil, nil)
    assert_equal "H: - I: -", result
  end

  # sqlcommenter_href tests

  test "sqlcommenter_href links a job tag to its own page" do
    database = PgPeek::Database.find("primary")

    result = sqlcommenter_href(database, { "job" => "PostAnalyticsJob" })

    assert_equal database_job_path(database, "PostAnalyticsJob"), result
  end

  test "sqlcommenter_href links a controller tag to the endpoints list" do
    database = PgPeek::Database.find("primary")

    result = sqlcommenter_href(database, { "controller" => "posts", "action" => "index" })

    assert_equal database_endpoints_path(database), result
  end

  test "sqlcommenter_href returns nil when there is nothing to link to" do
    database = PgPeek::Database.find("primary")

    assert_nil sqlcommenter_href(database, {})
    assert_nil sqlcommenter_href(database, { "application" => "Dummy" })
  end

  # duration tests: the unit scales with magnitude so values stay narrow and
  # comparable at a glance -- 210ms next to 1.20s, not 00:00:00.210 next to
  # 00:00:01.204.

  test "format_duration_from_ms picks a unit by magnitude" do
    assert_equal "2.0ms",  format_duration_from_ms(2)
    assert_equal "210ms",  format_duration_from_ms(210)
    assert_equal "1.20s",  format_duration_from_ms(1204)
    assert_equal "2m 05s", format_duration_from_ms(125_000)
    assert_equal "1h 12m", format_duration_from_ms(4_320_000)
  end

  test "format_duration_from_ms treats nothing as zero" do
    assert_equal "0ms", format_duration_from_ms(nil)
    assert_equal "0ms", format_duration_from_ms(0)
  end

  test "format_duration reads the ISO 8601 intervals a Rails connection returns" do
    assert_equal "210ms",   format_duration("PT0.21044S")
    assert_equal "1.20s",   format_duration("PT1.204S")
    assert_equal "2m 05s",  format_duration("PT2M5S")
    assert_equal "1h 12m",  format_duration("PT1H12M")
    assert_equal "26h 00m", format_duration("P1DT2H")
  end

  test "format_duration also reads the default interval text" do
    assert_equal "210ms",  format_duration("00:00:00.21")
    assert_equal "1.20s",  format_duration("00:00:01.204")
    assert_equal "2m 05s", format_duration("00:02:05")
    assert_equal "1h 12m", format_duration("01:12:00")
  end

  test "format_duration handles intervals that span days" do
    assert_equal "26h 00m", format_duration("1 day 02:00:00")
  end

  test "format_duration treats blank as zero" do
    assert_equal "0ms", format_duration(nil)
    assert_equal "0ms", format_duration("")
  end

  # intensity_bar tests

  test "intensity_bar always renders the same number of segments" do
    [ [ 0, 100 ], [ 1, 100 ], [ 50, 100 ], [ 100, 100 ], [ nil, nil ] ].each do |value, max|
      assert_equal 5, intensity_bar(value, max).scan("█").size,
                   "expected 5 segments for #{value.inspect}/#{max.inspect}"
    end
  end

  test "intensity_bar fills every segment at the maximum" do
    assert_equal 5, filled_segments(intensity_bar(100, 100))
  end

  test "intensity_bar fills no segments when there is nothing to compare against" do
    assert_equal 0, filled_segments(intensity_bar(nil, nil))
    assert_equal 0, filled_segments(intensity_bar(5, 0))
  end

  test "intensity_bar keeps a small value visible" do
    assert_equal 1, filled_segments(intensity_bar(1, 1000))
  end

  test "intensity_bar scales between the two" do
    assert_equal 3, filled_segments(intensity_bar(50, 100))
  end

  test "intensity_bar carries its level so the stylesheet can grade it" do
    assert_includes intensity_bar(100, 100), 'class="bar bar-5"'
    assert_includes intensity_bar(1, 1000), 'class="bar bar-1"'
    assert_includes intensity_bar(nil, nil), 'class="bar bar-0"'
  end

  test "intensity_bar is html_safe" do
    assert intensity_bar(1, 2).html_safe?
  end

  private

  def filled_segments(markup)
    markup[/class="bar-on">([█]*)</, 1].to_s.size
  end
end
