# Database cost per ActiveJob class, attributed through the `job` SQLcommenter
# tag. Queue depth, retries and failures belong to the job backend; this is the
# database's view of the same jobs.
class PgPeek::Reports::Jobs < PgPeek::Report
  title "Jobs"

  column :job_class, header: "job"
  column :total_exec_time_ms, header: "db time", align: :right, format: :duration_ms
  column :share, align: :right, format: :intensity, title: "Share of database time across jobs"
  column :total_calls, header: "queries", align: :right, format: :number
  column :query_count, header: "shapes", align: :right, format: :number,
                       title: "Distinct query shapes issued by this job"

  private
    def fetch_rows
      rows = pg_stat_statements.jobs
      return [] if rows.blank?

      rows.each do |row|
        # The job tag arrives url-encoded: Reports%3A%3ADigestJob.
        row["job_class"] = CGI.unescape(row["job_class"].to_s)
        row["share"] = row["total_exec_time_ms"]
      end
    end
end
