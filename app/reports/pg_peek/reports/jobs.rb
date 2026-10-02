# Database cost per ActiveJob class, attributed through the `job` SQLcommenter
# tag. Queue depth, retries and failures belong to the job backend; this is the
# database's view of the same jobs.
class PgPeek::Reports::Jobs < PgPeek::Report
  title "Jobs"

  column :job_class, header: "job", format: :name
  column :total_exec_time_ms, header: "db time", align: :right, format: :duration_ms, bar: true,
                             title: "Database time; the bar compares it with the other jobs listed"
  column :total_calls, header: "queries", align: :right, format: :number
  column :query_count, header: "shapes", align: :right, format: :number,
                       title: "Distinct query shapes issued by this job"

  private
    def fetch_rows
      pg_stat_statements.jobs.to_a.each do |row|
        # The job tag arrives url-encoded: Reports%3A%3ADigestJob.
        row["job_class"] = CGI.unescape(row["job_class"].to_s)
      end
    end
end
