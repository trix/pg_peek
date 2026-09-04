# The query shapes one job class issues, most expensive first.
class PgPeek::Reports::JobQueries < PgPeek::Report
  title "Queries"

  column :calls, align: :right, format: :intensity, title: "Call count relative to this job's other queries"
  column :total_exec_time, header: "db time", align: :right, format: :duration
  column :prop_exec_time, header: "share", align: :right
  column :avg_exec_ms, header: "avg ms", align: :right, format: :number
  column :query, format: :sql

  attr_reader :job_class

  def initialize(database:, job_class:)
    super(database: database)
    @job_class = job_class
  end

  private
    def fetch_rows
      rows = pg_stat_statements.outliers_by_job(job_class)
      return [] if rows.blank?

      # ncalls arrives already formatted with separators; the bar needs a number.
      rows.each { |row| row["calls"] = row["ncalls"].to_s.delete(",").to_i }
    end
end
