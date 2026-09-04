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
    when :sql          then tag.code(strip_sqlcommenter(value.to_s).squish, class: "sql")
    when :intensity    then intensity_bar(value.to_f, report.max_for(column))
    else value.to_s
    end
  end

  # The compact figure is what you scan; the exact one is a hover away.
  def duration_cell(ms)
    tag.span(format_duration_from_ms(ms), title: "#{number_with_delimiter(ms.round(1))} ms")
  end

  def cell_class(column)
    case column.format
    when :intensity then "intensity"
    else column.numeric? ? "num" : nil
    end
  end
end
