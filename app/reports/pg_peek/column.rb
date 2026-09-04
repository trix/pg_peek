# One column of a report: what to read from a row, how to label it, and how the
# value should be drawn. Renderers decide what those choices mean -- the HTML
# table right-aligns, a terminal renderer pads -- so a column stays free of
# either.
class PgPeek::Column
  ALIGNMENTS = %i[left right].freeze

  attr_reader :key, :align, :format, :title

  def initialize(key, header: nil, align: :left, format: :text, title: nil)
    raise ArgumentError, "unknown alignment #{align.inspect}" unless ALIGNMENTS.include?(align)

    @key = key
    @header = header
    @align = align
    @format = format
    @title = title
  end

  def header
    @header || key.to_s.tr("_", " ")
  end

  def numeric?
    align == :right
  end
end
