module PgPeek::ApplicationHelper
  # Where the current section lives in another database. Detail pages fall back
  # to their section, since the other database may not have that table or job.
  def switch_database_path(database)
    case controller_name
    when "pg_stat_statements" then database_pg_stat_statements_path(database)
    when "endpoints"          then database_endpoints_path(database)
    when "jobs"               then database_jobs_path(database)
    when "indexes"            then database_indexes_path(database)
    when "activity"           then database_activity_path(database)
    else database_path(database)
    end
  end

  KNOWN_KEYS = %w[application controller namespaced_controller action job].freeze

  # example sql comment: /*action='show',application='Trmz',namespaced_controller='staff%2Fprocesses%2Fprocesses'*/

  SQLCOMMENTER_PATTERN = %r{
    \s*                     # optional leading whitespace
    /\*                     # opening /*
    (?:                     # one or more key:value pairs
      [a-zA-Z_][a-zA-Z0-9_]*  # key (starts with letter/underscore)
      =                       # colon
      [^:*]*                  # value (anything except * or : to avoid breaking */
    \s*)+
    \*/                     # closing */
    \s*                     # optional trailing whitespace
  }xi

  def strip_sqlcommenter(sql)
    sql.gsub(SQLCOMMENTER_PATTERN, "").strip
  end

  def extract_comment(sql)
    comment_value = sql.scan(SQLCOMMENTER_PATTERN).first&.squish

    # strip opening and closing comment markers from the SQL comment
    comment_value&.gsub(/^\/\*/, "")&.gsub(/\*\/$/, "")
  end

  def sqlcommenter_to_hash(comment)
    comment.split(",").each_with_object({}) do |pair, hash|
      key, value = pair.split("=")
      hash[key] = value
    end
  end

  # Format a rate with auto-scaled units based on magnitude
  def format_rate(count, seconds_elapsed)
    return "N/A" if seconds_elapsed.nil? || seconds_elapsed.zero? || count.nil?

    per_second = count.to_f / seconds_elapsed

    formatted = case per_second
    when 0...0.017      # < 1/min
      "#{format_number((per_second * 86400).round(1))}/day"
    when 0.017...1      # < 1/sec
      "#{format_number((per_second * 3600).round(1))}/hr"
    when 1...60         # < 60/sec
      "#{format_number((per_second * 60).round(1))}/min"
    else
      "#{format_number(per_second.round(1))}/s"
    end

    "(~#{formatted})"
  end

  # Format a count with its rate
  def format_count_with_rate(count, seconds_elapsed)
    return "N/A" if count.nil?

    formatted_count = format_number(count)
    rate = format_rate(count, seconds_elapsed)

    if rate == "N/A"
      formatted_count
    else
      "#{formatted_count} #{rate}"
    end
  end

  # Format a number with thousands separators
  def format_number(number)
    return "N/A" if number.nil?
    number_with_delimiter(number)
  end

  # Format a percentage, returning "N/A" for nil
  def format_percentage(value)
    return "N/A" if value.nil?
    "#{value}%"
  end

  # Format a timestamp as relative time (e.g., "3 hours ago")
  def format_time_ago(timestamp)
    return "Never" if timestamp.nil?
    time_ago_in_words(timestamp) + " ago"
  end

  # Format cache hit ratio for inline display
  def format_inline_cache_stats(heap_ratio, index_ratio)
    heap_display = heap_ratio.nil? ? "-" : "#{heap_ratio}%"
    index_display = index_ratio.nil? ? "-" : "#{index_ratio}%"
    "H: #{heap_display} I: #{index_display}"
  end

  # Horizontal bar meter for call intensity visualization
  # Returns a 5-segment bar: ██░░░ (low) → █████ (high)
  INTENSITY_SEGMENTS = 5

  # One character throughout, with colour rather than shading separating the
  # filled part from the rest: mixed block glyphs vary in weight between fonts
  # and read as noise at this size.
  def intensity_bar(value, max_value)
    filled = intensity_segments(value, max_value)

    # The level class lets the stylesheet brighten the bar with its value.
    tag.span(class: "bar bar-#{filled}") do
      tag.span("█" * filled, class: "bar-on") +
        tag.span("█" * (INTENSITY_SEGMENTS - filled), class: "bar-off")
    end
  end

  # A non-zero value always keeps one segment lit, so "rare but present" is
  # distinguishable from "absent" at a glance.
  def intensity_segments(value, max_value)
    return 0 if value.nil? || max_value.nil? || max_value.zero?

    ((value.to_f / max_value) * INTENSITY_SEGMENTS).ceil.clamp(0, INTENSITY_SEGMENTS)
  end

  # Durations pick their unit by magnitude: 210ms, 1.20s, 2m 05s, 1h 12m.
  # Values stay narrow and read at a glance, and a header sits over data of
  # similar width. The exact figure belongs in a title, not the cell.
  def format_duration_from_ms(total_ms)
    ms = total_ms.to_f
    return "0ms" if ms <= 0
    return format("%.1fms", ms) if ms < 10
    return "#{ms.round}ms" if ms < 1000

    seconds = ms / 1000.0
    return format("%.2fs", seconds) if seconds < 60

    minutes, secs = seconds.divmod(60)
    return format("%dm %02ds", minutes, secs) if minutes < 60

    hours, mins = minutes.divmod(60)
    format("%dh %02dm", hours, mins)
  end

  # Rails sets intervalstyle = iso_8601 on its connections, so an interval
  # arrives as "PT1.204S". Anything else -- a raw psql connection, or a host
  # that overrides the style -- renders as "HH:MM:SS.fff" with a "N days"
  # prefix once long enough. Both are read.
  def format_duration(interval_text)
    format_duration_from_ms(interval_to_ms(interval_text))
  end

  def interval_to_ms(interval_text)
    text = interval_text.to_s.strip
    return 0.0 if text.empty?
    return ActiveSupport::Duration.parse(text).to_f * 1000.0 if text.start_with?("P")

    days = text[/(\d+)\s+days?/, 1].to_i
    hours = minutes = seconds = 0.0
    if (match = text.match(/(\d+):(\d{2}):(\d{2}(?:\.\d+)?)/))
      hours, minutes, seconds = match[1].to_i, match[2].to_i, match[3].to_f
    end

    (days * 86_400 + hours * 3600 + minutes * 60 + seconds) * 1000.0
  rescue ActiveSupport::Duration::ISO8601Parser::ParsingError
    0.0
  end

  # Comment icon SVG for SQLcommenter tooltip
  def comment_icon_svg
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="14" height="14" fill="currentColor" style="vertical-align: middle;"><path d="M123.6 391.3c12.9-9.4 29.6-11.8 44.6-6.4c26.5 9.6 56.2 15.1 87.8 15.1c124.7 0 208-80.5 208-160S380.7 80 256 80S48 160.5 48 240c0 32 12.4 62.8 35.7 89.2c8.6 9.7 12.8 22.5 11.8 35.5c-1.4 18.1-5.7 34.7-11.3 49.4c17-7.9 31.1-16.7 39.4-22.7zM256 512c-38.4 0-75.1-5.5-109.8-15.7c-10.2 6.9-25.2 15.8-43.5 24.2C76.5 531.7 46.4 540.6 16 542c-4.9 .2-9.4-2.8-11-7.4s.1-9.8 4-12.5c16-11.3 28-26.8 35.3-45.2c1.5-3.8 2.8-7.7 4-11.6C16.8 428.8 0 386.3 0 340c0-106 94.8-192 212-192c8.5 0 16.8 .4 25 1.2C266.1 53.5 347.5 0 442 0C529.3 0 600 57.2 600 128c0 32.6-14.3 62.5-38.5 85.8c3.9 10.4 6.5 21.5 6.5 33.2c0 106-94.8 192-212 192c-57.2 0-109.4-17.8-148.3-47.3C182.1 403.8 155.4 412 128 412c-17.6 0-34.7-2.3-50.8-6.6c14.4 36.9 47.9 69.3 96.5 88.5C194.5 506.2 224.5 512 256 512z"/></svg>'.html_safe
  end

  # Chart icon SVG for table stats link
  def chart_icon_svg
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="16" height="16" fill="currentColor" style="vertical-align: middle;"><path d="M64 64c0-17.7-14.3-32-32-32S0 46.3 0 64L0 400c0 44.2 35.8 80 80 80l400 0c17.7 0 32-14.3 32-32s-14.3-32-32-32L80 416c-8.8 0-16-7.2-16-16L64 64zm406.6 86.6c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0L320 210.7l-57.4-57.4c-12.5-12.5-32.8-12.5-45.3 0l-112 112c-12.5 12.5-12.5 32.8 0 45.3s32.8 12.5 45.3 0L240 221.3l57.4 57.4c12.5 12.5 32.8 12.5 45.3 0l128-128z"/></svg>'.html_safe
  end
end
