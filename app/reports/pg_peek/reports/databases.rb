# The databases pg_peek can open, and whether each is actually collecting
# statistics. Whether a database is worth visiting is the question this page
# answers, so the extension's state belongs in the list rather than behind a
# click.
class PgPeek::Reports::Databases < PgPeek::Report
  title "Databases"

  column :name, header: "database"
  column :role
  column :version, align: :right
  column :statistics, title: "State of the pg_stat_statements extension"
  column :tables, align: :right, format: :number

  def initialize(databases:)
    super(database: nil)
    @databases = databases
  end

  private
    def fetch_rows
      @databases.map do |database|
        pg_stat = PgPeek::PgStatStatements.new(database: database)

        { "name" => database.name,
          "role" => role_for(database),
          "version" => database.version,
          "statistics" => statistics_for(pg_stat),
          "tables" => database.tables.size,
          "database" => database }
      end
    end

    def role_for(database)
      return "primary" if database.primary
      return "replica" if database.replica

      ""
    end

    def statistics_for(pg_stat)
      return "not available" unless pg_stat.available?
      return "not installed" unless pg_stat.installed?
      return "not preloaded" unless pg_stat.preloaded?

      "collecting · #{pg_stat.installed_version}"
    end
end
