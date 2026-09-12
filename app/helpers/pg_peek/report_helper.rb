# Turns a report cell into markup. The report is passed alongside the column
# because some formats are relative -- an intensity bar means nothing without
# the largest value in its column.
module PgPeek::ReportHelper
  def format_cell(report, column, row)
    value = row.value(column)
    return "" if value.nil? || value.to_s.empty?

    case column.format
    when :number       then format_number(value.to_i)
    when :duration_ms  then duration_cell(value.to_f)
    when :duration     then duration_cell(interval_to_ms(value))
    when :percent      then "#{value}%"
    when :ratio        then "~#{value}"
    when :sql          then sql_cell(report, value.to_s)
    when :intensity    then intensity_bar(value.to_f, report.max_for(column))
    else value.to_s
    end
  end

  # The compact figure is what you scan; the exact one is a hover away.
  def duration_cell(ms)
    tag.span(format_duration_from_ms(ms), title: "#{number_with_delimiter(ms.round(1))} ms")
  end

  # The SQL text, plus -- when SQLcommenter tagged it -- what issued it (a
  # link into the page that already aggregates this exact query across every
  # call site) and every raw tag behind a disclosure, for the rest.
  def sql_cell(report, sql)
    code = tag.code(strip_sqlcommenter(sql).squish, class: "sql")
    tags = PgPeek::SqlComment.tags(sql)
    return code if tags.empty?

    safe_join([ code, sql_source(report, tags), sql_tags(tags) ].compact)
  end

  def sql_source(report, tags)
    label = PgPeek::SqlComment.label(tags)
    return nil unless label

    href = report.database && sqlcommenter_href(report.database, tags)
    tag.div(safe_join([ "→ ", href ? link_to(label, href) : label ]), class: "dim")
  end

  def sql_tags(tags)
    tag.details(safe_join([
      tag.summary("tags"),
      tag.pre(tags.map { |key, value| "#{key}: #{value}" }.join("\n"))
    ]), class: "tags")
  end

  def cell_class(column)
    case column.format
    when :intensity then "intensity"
    else column.numeric? ? "num" : nil
    end
  end
end
