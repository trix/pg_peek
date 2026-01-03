module PgPeek
  module ApplicationHelper
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

    # Chart icon SVG for table stats link
    def chart_icon_svg
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="16" height="16" fill="currentColor" style="vertical-align: middle;"><path d="M64 64c0-17.7-14.3-32-32-32S0 46.3 0 64L0 400c0 44.2 35.8 80 80 80l400 0c17.7 0 32-14.3 32-32s-14.3-32-32-32L80 416c-8.8 0-16-7.2-16-16L64 64zm406.6 86.6c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0L320 210.7l-57.4-57.4c-12.5-12.5-32.8-12.5-45.3 0l-112 112c-12.5 12.5-12.5 32.8 0 45.3s32.8 12.5 45.3 0L240 221.3l57.4 57.4c12.5 12.5 32.8 12.5 45.3 0l128-128z"/></svg>'.html_safe
    end
  end
end
