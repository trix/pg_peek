# Database cost per controller#action, attributed through SQLcommenter tags.
class PgPeek::Reports::Endpoints < PgPeek::Report
  title "Endpoints"

  # Above this, a query is running many times per request rather than a few:
  # the shape of an N+1 rather than a page that legitimately asks twice.
  N_PLUS_ONE_THRESHOLD = 5

  column :endpoint, format: :name
  column :total_exec_time_ms, header: "db time", align: :right, format: :duration_ms, bar: true,
                             title: "Database time; the bar compares it with the other endpoints listed"
  column :request_count, header: "requests", align: :right, format: :number,
                         title: "Estimated from the least-called query of this endpoint"
  column :total_calls, header: "queries", align: :right, format: :number
  column :query_count, header: "shapes", align: :right, format: :number
  column :total_rows, header: "rows", align: :right, format: :number
  column :max_queries_per_request, header: "q/req", align: :right, format: :ratio,
                                   title: "Worst queries-per-request in this endpoint. An estimate, not a measurement."

  def self.n_plus_one?(row)
    row["max_queries_per_request"].to_f >= N_PLUS_ONE_THRESHOLD
  end

  private
    def fetch_rows
      rows = pg_stat_statements.endpoints
      return [] if rows.blank?

      # namespaced_controller arrives url-encoded: staff%2Fprocesses#show.
      rows.each { |row| row["endpoint"] = CGI.unescape(row["endpoint"].to_s) }
    end
end
