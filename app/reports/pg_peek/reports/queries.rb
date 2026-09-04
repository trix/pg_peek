# The most expensive query shapes in the database.
class PgPeek::Reports::Queries < PgPeek::Report
  title "Queries"

  column :calls, align: :right, format: :intensity, title: "Call count relative to the other queries listed"
  column :total_exec_time, header: "db time", align: :right, format: :duration
  column :prop_exec_time, header: "share", align: :right
  column :avg_exec_ms, header: "avg ms", align: :right, format: :number
  column :query, format: :sql

  private
    def fetch_rows
      rows = source_rows
      return [] if rows.blank?

      # ncalls arrives already formatted with separators; the bar needs a number.
      rows.each { |row| row["calls"] = row["ncalls"].to_s.delete(",").to_i }
    end

    def source_rows
      pg_stat_statements.outliers
    end
end
