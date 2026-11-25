# The statements the whole application issues, which the endpoint and job
# breakdowns leave out because their tags name only whoever ran them first.
class PgPeek::Reports::SharedQueries < PgPeek::Reports::Queries
  title "Shared statements"

  # The tags on these are the reason they are here: they name one caller of many.
  def attributed? = false

  private
    def source_rows
      pg_stat_statements.shared_statements
    end
end
