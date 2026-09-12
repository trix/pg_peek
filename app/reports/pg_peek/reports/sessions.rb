# Every other client session on the database right now, the busiest first:
# blocked sessions, then running queries by age, then open transactions by
# age, then idle connections. Unlike every other report this is a snapshot,
# not a sum since the last reset.
class PgPeek::Reports::Sessions < PgPeek::Report
  title "Sessions"

  HIDDEN_QUERY = "<insufficient privilege>".freeze

  column :pid, align: :right
  column :state
  column :duration_ms, header: "for", align: :right, format: :duration_ms,
         title: "Active: how long the current query has run. Idle in transaction: age of the open transaction. Idle: time since the last query finished."
  column :wait, title: "What the session is waiting on: another session's lock, IO, its client -- or nothing, which means CPU"
  column :source, title: "Endpoint or job from the query's SQLcommenter tags, otherwise the application name"
  column :query, format: :sql

  def active = rows.select { |row| row["state"] == "active" }
  def idle = rows.select { |row| row["state"] == "idle" }
  def in_transaction = rows.select { |row| row["state"].to_s.start_with?("idle in transaction") }
  def blocked = rows.select { |row| row["blocked_by"].any? }

  # Everything an operator would look at; idle connections are a pool doing
  # its job.
  def busy = rows.reject { |row| row["state"] == "idle" }

  def long_running(threshold_ms)
    active.select { |row| row["duration_ms"].to_i >= threshold_ms }
  end

  def stale_transactions(threshold_ms)
    in_transaction.select { |row| row["duration_ms"].to_i >= threshold_ms }
  end

  # PostgreSQL shows a session's query text only to its own user, superusers
  # and members of pg_read_all_stats. Anything else reads as a placeholder.
  def hidden_queries?
    rows.any? { |row| row["query"] == HIDDEN_QUERY }
  end

  private
    def fetch_rows
      rows = database.sessions

      rows.each do |row|
        row["blocked_by"] = row["blocked_by"].to_s.split(",").map(&:to_i)
        row["duration_ms"] = duration_for(row)
        row["wait"] = wait_for(row)
        row["source"] = source_for(row)
      end

      rows.sort_by { |row| [ priority(row), -row["duration_ms"].to_i, row["pid"].to_i ] }
    end

    def priority(row)
      return 0 if row["blocked_by"].any?

      case row["state"]
      when "active" then 1
      when "idle" then 3
      else 2
      end
    end

    # The figure that matters depends on what the session is doing: a running
    # query's age, an open transaction's age, or how long a connection has
    # sat unused.
    def duration_for(row)
      value = case row["state"]
      when "active" then row["query_ms"]
      when "idle" then row["state_ms"]
      else row["xact_ms"] || row["state_ms"]
      end
      value&.to_i
    end

    def wait_for(row)
      return "blocked by #{row["blocked_by"].join(", ")}" if row["blocked_by"].any?
      return "" if row["wait_event_type"].blank?

      "#{row["wait_event_type"].downcase}: #{row["wait_event"]}"
    end

    def source_for(row)
      tags = PgPeek::SqlComment.tags(row["query"])
      PgPeek::SqlComment.label(tags) || row["application_name"].presence || ""
    end
end
