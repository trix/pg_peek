# Every table in the database with the cache ratios already fetched in one
# round trip by Table.inline_stats_for.
class PgPeek::Reports::Tables < PgPeek::Report
  title "Tables"

  column :name, header: "table"
  column :heap_hit_ratio, header: "heap cache", align: :right, format: :percent,
                          title: "Share of heap block reads served from cache"
  column :index_hit_ratio, header: "index cache", align: :right, format: :percent,
                           title: "Share of index block reads served from cache"

  private
    def fetch_rows
      names = database.tables
      stats = PgPeek::Table.inline_stats_for(database, names)

      names.map do |name|
        row = stats[name] || {}

        { "name" => name,
          "heap_hit_ratio" => row[:heap_hit_ratio],
          "index_hit_ratio" => row[:index_hit_ratio] }
      end
    end
end
