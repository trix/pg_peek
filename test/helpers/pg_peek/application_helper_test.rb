require "test_helper"

class PgPeek::ApplicationHelperTest < ActionView::TestCase
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

  # chart_icon_svg tests
  test "chart_icon_svg returns svg element" do
    result = chart_icon_svg
    assert_match(/<svg.*<\/svg>/, result)
  end

  test "chart_icon_svg is html_safe" do
    result = chart_icon_svg
    assert result.html_safe?
  end
end
