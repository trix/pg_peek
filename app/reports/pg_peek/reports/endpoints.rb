# Database cost per controller#action, attributed through SQLcommenter tags.
class PgPeek::Reports::Endpoints < PgPeek::Report
  title "Endpoints"

  # Above this, a query is running many times per request rather than a few:
  # the shape of an N+1 rather than a page that legitimately asks twice.
  N_PLUS_ONE_THRESHOLD = 5

  column :endpoint
  column :total_exec_time_ms, header: "db time", align: :right, format: :duration_ms
  column :share, align: :right, format: :intensity, title: "Share of database time across endpoints"
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

      rows.each do |row|
        # namespaced_controller arrives url-encoded: staff%2Fprocesses#show.
        row["endpoint"] = CGI.unescape(row["endpoint"].to_s)
        row["share"] = row["total_exec_time_ms"]
      end
    end
end
