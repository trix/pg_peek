# A report is columns plus rows, and nothing about how either is drawn.
#
# Every angle pg_peek offers -- queries, endpoints, jobs, tables -- is one of
# these, so a new angle is a subclass and a .sql file rather than a controller,
# a view and its own styling. It also means a terminal renderer can draw the
# same report as the HTML one, from the same declaration.
class PgPeek::Report
  class Row
    def initialize(attributes) = @attributes = attributes

    def value(column) = @attributes[column.key.to_s]
    def [](key) = @attributes[key.to_s]
    def to_h = @attributes
  end

  class_attribute :columns, instance_writer: false, default: []

  attr_reader :database

  class << self
    def title(value = nil)
      @title = value if value
      @title || name.demodulize.titleize
    end

    def column(key, **options)
      # Subclasses get their own array rather than appending to the parent's.
      self.columns = columns + [ PgPeek::Column.new(key, **options) ]
    end
  end

  # Most reports describe one database. A few -- the database list itself --
  # describe the set of them, and pass nothing.
  def initialize(database: nil)
    @database = database
  end

  def rows
    @rows ||= fetch_rows.map { |attributes| Row.new(attributes) }
  end

  def empty? = rows.empty?

  def title = self.class.title

  # Relative formats -- an intensity bar, a share of total -- need the extent of
  # the column, not just the cell.
  def max_for(column)
    @maxima ||= {}
    @maxima[column.key] ||= rows.filter_map { |row| row.value(column)&.to_f }.max
  end

  private
    # Subclasses return an array of hashes keyed by column name, which is what
    # PG::Result already yields.
    def fetch_rows
      raise NotImplementedError, "#{self.class} must define #fetch_rows"
    end

    def pg_stat_statements
      @pg_stat_statements ||= PgPeek::PgStatStatements.new(database: database)
    end
end
