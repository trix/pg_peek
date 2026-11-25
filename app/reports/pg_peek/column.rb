# One column of a report: what to read from a row, how to label it, and how the
# value should be drawn. Renderers decide what those choices mean -- the HTML
# table right-aligns, a terminal renderer pads -- so a column stays free of
# either.
class PgPeek::Column
  ALIGNMENTS = %i[left right].freeze

  attr_reader :key, :align, :format, :title

  # bar: draw the value with a bar next to it, scaled against the largest value
  # in the column, so the biggest rows stand out without reading every figure.
  #
  # dim and caption depend on the row, so each is a proc that takes one.
  # dim: true where the value is there for completeness rather than attention.
  # caption: a few words saying what the value is, where that differs from row
  # to row.
  def initialize(key, header: nil, align: :left, format: :text, title: nil, bar: false, dim: nil, caption: nil)
    raise ArgumentError, "unknown alignment #{align.inspect}" unless ALIGNMENTS.include?(align)

    @key = key
    @header = header
    @align = align
    @format = format
    @title = title
    @bar = bar
    @dim = dim
    @caption = caption
  end

  def header
    @header || key.to_s.tr("_", " ")
  end

  def bar? = @bar

  def dim?(row) = @dim ? !!@dim.call(row) : false

  def caption(row) = @caption&.call(row).presence

  def numeric?
    align == :right
  end
end
