# The query shapes one controller#action issues, most expensive first.
class PgPeek::Reports::EndpointQueries < PgPeek::Reports::Queries
  attr_reader :endpoint

  def initialize(database:, endpoint:)
    super(database: database)
    @endpoint = endpoint
  end

  private
    def source_rows
      pg_stat_statements.outliers_by_endpoint(endpoint)
    end
end
