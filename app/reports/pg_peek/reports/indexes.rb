# Every index in the database, unused ones first. "Unused" means never scanned
# since the statistics were last reset and not enforcing a constraint --
# primary keys and unique indexes do their work on writes, whether or not a
# query ever reads them.
#
# PostgreSQL 19 records the reset per index, so one whose counters were reset
# on their own is judged by its own, shorter window rather than the
# database's.
class PgPeek::Reports::Indexes < PgPeek::Report
  title "Indexes"

  column :table_name, header: "table"
  column :index_name, header: "index"
  column :kind
  column :size, align: :right
  column :scans, align: :right, format: :number, title: "Scans since statistics were last reset"
  column :note

  def unused
    rows.select { |row| row["unused"] }
  end

  def unused_bytes
    unused.sum { |row| row["size_bytes"].to_i }
  end

  # Unused over a window of at least this long. Scan counts restart at zero on
  # a reset, so right after one every index looks unused.
  def unused_for(duration)
    unused.select { |row| row["stats_reset"].nil? || row["stats_reset"] < duration.ago }
  end

  private
    def fetch_rows
      rows = database.indexes.reject { |row| PgPeek::Table.excluded?(row["table_name"]) }

      rows.each do |row|
        primary = truthy?(row["primary_key"])
        unique = truthy?(row["unique_index"])

        row["kind"] = primary ? "primary key" : (unique ? "unique" : "")
        row["unused"] = row["scans"].to_i.zero? && !primary && !unique

        # A reset of the whole database stamps every index with the database's
        # own time, so a later one means this index was reset by itself.
        own_reset_at = time(row["stats_reset"])
        reset_alone = own_reset_at && (database_reset_at.nil? || own_reset_at > database_reset_at)
        row["stats_reset"] = own_reset_at || database_reset_at

        row["note"] = [
          ("unused" if row["unused"]),
          ("scans counted since #{own_reset_at.utc.to_date.iso8601}" if reset_alone)
        ].compact.join(", ")
      end

      rows.sort_by { |row| [ row["unused"] ? 0 : 1, -row["size_bytes"].to_i, row["table_name"], row["index_name"] ] }
    end

    def database_reset_at
      return @database_reset_at if defined?(@database_reset_at)

      @database_reset_at = database.stats_reset_at
    end

    # A time or its text, depending on the adapter's type map.
    def time(value)
      value.is_a?(Time) ? value : (Time.zone.parse(value.to_s) if value.present?)
    end

    # Raw results hand booleans over as "t"/"f" or true/false depending on
    # the adapter's type map.
    def truthy?(value)
      ActiveModel::Type::Boolean.new.cast(value) == true
    end
end
