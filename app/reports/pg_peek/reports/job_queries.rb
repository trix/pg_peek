# The query shapes one job class issues, most expensive first.
class PgPeek::Reports::JobQueries < PgPeek::Reports::Queries
  attr_reader :job_class

  def initialize(database:, job_class:)
    super(database: database)
    @job_class = job_class
  end

  private
    def source_rows
      pg_stat_statements.outliers_by_job(job_class)
    end
end
