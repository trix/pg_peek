# Every index in the database, unused ones first. "Unused" means never scanned
# since the statistics were last reset and not enforcing a constraint --
# primary keys and unique indexes do their work on writes, whether or not a
# query ever reads them.
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

  private
    def fetch_rows
      rows = database.indexes.reject { |row| PgPeek::Table.excluded?(row["table_name"]) }

      rows.each do |row|
        primary = truthy?(row["primary_key"])
        unique = truthy?(row["unique_index"])

        row["kind"] = primary ? "primary key" : (unique ? "unique" : "")
        row["unused"] = row["scans"].to_i.zero? && !primary && !unique
        row["note"] = row["unused"] ? "unused" : ""
      end

      rows.sort_by { |row| [ row["unused"] ? 0 : 1, -row["size_bytes"].to_i, row["table_name"], row["index_name"] ] }
    end

    # Raw results hand booleans over as "t"/"f" or true/false depending on
    # the adapter's type map.
    def truthy?(value)
      ActiveModel::Type::Boolean.new.cast(value) == true
    end
end
