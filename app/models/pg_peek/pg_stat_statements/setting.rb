# One pg_stat_statements.* setting: its value, and what there is to know before
# changing it. What the values are and how a change takes effect come from
# pg_settings, so they are the server's own; what the setting means for the
# figures pg_peek shows is written here.
class PgPeek::PgStatStatements::Setting
  PREFIX = "pg_stat_statements.".freeze

  ABOUT = {
    "max" => {
      does: "How many distinct statements the server keeps statistics for, across every database on it. " \
            "When the table is full the least-executed statements are dropped to make room, and their calls " \
            "and time go with them: \"dropped when full\" above counts those, and once it is above zero every " \
            "total undercounts."
    },
    "save" => {
      does: "Whether the statistics are kept across a server restart.",
      values: {
        "on" => "Written to disk at shutdown and loaded again at start, so the window runs on through a restart.",
        "off" => "Every restart begins from nothing."
      }
    },
    "track" => {
      does: "Which statements are counted.",
      values: {
        "top" => "The statements clients send. What a function or procedure runs inside is counted as part of " \
                 "the call to it.",
        "all" => "Those, and the statements run inside functions and procedures, each as a row of its own. Their " \
                 "time is then counted twice, on their own row and in the statement that called them, so totals " \
                 "read high.",
        "none" => "Nothing is collected, and every page that reads the extension stays empty."
      }
    },
    "track_planning" => {
      does: "Whether the time spent planning a statement is recorded next to the time spent executing it. " \
            "The figures pg_peek shows are execution time either way.",
      values: {
        "on" => "Planning is recorded. On a busy server it has a cost: connections running the same statement " \
                "contend to update its one row.",
        "off" => "Only execution is recorded."
      }
    },
    "track_utility" => {
      does: "Whether utility commands are counted: everything other than SELECT, INSERT, UPDATE, DELETE and " \
            "MERGE, so BEGIN, COMMIT, NOTIFY, SET, DDL and the rest.",
      values: {
        "on" => "They are counted. A command whose text carries a literal, as a NOTIFY payload does, takes a row " \
                "for each distinct text, which can fill the table.",
        "off" => "Only queries and data changes are counted. pg_peek leaves transaction and session commands " \
                 "out of the endpoint and job breakdowns either way."
      }
    }
  }.freeze

  # pg_settings.context: when a new value takes effect, and who may set it.
  CHANGES = {
    "postmaster" => "needs a server restart",
    "sighup" => "set in the server's configuration; takes effect on a reload, no restart",
    "superuser" => "a superuser can change it with ALTER SYSTEM and a reload, or SET for one session; no restart",
    "user" => "any role can SET it for its own session",
    "internal" => "fixed when the server was built"
  }.freeze

  attr_reader :name, :value, :default

  def initialize(row)
    @row = row
    @name = row["name"].to_s.delete_prefix(PREFIX)
    @value = row["setting"]
    @default = row["boot_val"]
  end

  def full_name = "#{PREFIX}#{name}"

  # The server's own one-line description stands in for a setting this file
  # has not heard of, as a newer version of the extension may add.
  def does
    ABOUT.dig(name, :does) || @row["short_desc"]
  end

  # Each value the setting takes, with what it means where that is known.
  # Empty for a number: it has a range instead.
  def values
    allowed.index_with { |value| ABOUT.dig(name, :values, value) }
  end

  def range
    return unless numeric? && @row["min_val"].present? && @row["max_val"].present?

    [ @row["min_val"], @row["max_val"] ]
  end

  def change
    CHANGES[@row["context"]] || @row["context"]
  end

  def pending_restart?
    @row["pending_restart"] == true
  end

  private
    def numeric? = %w[integer real].include?(@row["vartype"])

    def allowed
      case @row["vartype"]
      when "bool" then %w[on off]
      when "enum" then PG::TextDecoder::Array.new.decode(@row["enumvals"].to_s)
      else []
      end
    end
end
