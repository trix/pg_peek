# Sessions waiting for a lock, and who holds it. Built from the sessions
# report rather than a second look at pg_stat_activity, so both tables on the
# page describe the same instant.
class PgPeek::Reports::Blocked < PgPeek::Report
  title "Blocked sessions"

  column :pid, align: :right, title: "The waiting session"
  column :waiting_for
  column :duration_ms, header: "for", align: :right, format: :duration_ms, title: "How long the waiting query has run"
  column :source, title: "Endpoint or job of the waiting session"
  column :blocked_by, align: :right, title: "The session holding the lock"
  column :blocker, title: "State and source of the session holding the lock"
  column :blocker_query, header: "blocker's query", format: :sql

  def initialize(database:, sessions: nil)
    super(database: database)
    @sessions = sessions || PgPeek::Reports::Sessions.new(database: database)
  end

  def any? = rows.any?

  private
    attr_reader :sessions

    def fetch_rows
      blocked = sessions.blocked
      return [] if blocked.empty?

      by_pid = sessions.rows.index_by { |row| row["pid"].to_i }
      locks = database.waiting_locks.index_by { |row| row["pid"].to_i }

      blocked.map do |row|
        blockers = row["blocked_by"].map { |pid| by_pid[pid] }.compact

        {
          "pid" => row["pid"],
          "waiting_for" => describe(locks[row["pid"].to_i]),
          "duration_ms" => row["query_ms"],
          "source" => row["source"],
          "blocked_by" => row["blocked_by"].join(", "),
          "blocker" => blockers.map { |b| [ b["state"], b["source"] ].compact_blank.join(" · ") }.join("; ").presence || "a session on another database",
          "blocker_query" => blockers.map { |b| b["query"] }.compact_blank.join("\n")
        }
      end
    end

    # "access exclusive lock on posts", "advisory lock (exclusive)",
    # "transactionid lock (share)" -- the last is what a row-level conflict
    # looks like from pg_locks.
    def describe(lock)
      return "a lock" unless lock

      mode = lock["mode"].to_s.delete_suffix("Lock").underscore.tr("_", " ")
      if lock["relation"].present?
        "#{mode} lock on #{lock["relation"]}"
      else
        "#{lock["locktype"]} lock (#{mode})"
      end
    end
end
