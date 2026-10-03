# Lays a query out one clause per line, so the first lines of a long query say
# what it reads and from where, and its joins and conditions read as a list.
# Only line breaks and spacing change. Breaks go in at the top level only --
# never inside parentheses, quotes or a CASE -- so subqueries and function
# calls stay on one line, and a query this does not understand comes out with
# an odd break at worst.
class PgPeek::SqlFormat
  TOKEN = /'(?:[^']|'')*'|"(?:[^"]|"")*"|[(),;]|[^\s'"(),;]+|\s+/
  CLAUSES = %w[SELECT FROM WHERE GROUP HAVING WINDOW ORDER LIMIT OFFSET FETCH FOR
               UNION INTERSECT EXCEPT RETURNING SET VALUES].freeze
  JOIN_PREFIXES = %w[INNER LEFT RIGHT FULL CROSS NATURAL].freeze
  CONDITIONS = %w[WHERE HAVING].freeze

  def self.format(sql)
    tokens = []
    space = false
    sql.to_s.strip.scan(TOKEN) do |token|
      if token.match?(/\A\s/)
        space = true
      else
        tokens << [ token, space ]
        space = false
      end
    end

    out = +""
    depth = case_depth = 0
    clause = nil
    between = false

    tokens.each_with_index do |(token, space_before), index|
      word = token.upcase
      top = index.positive? && depth.zero? && case_depth.zero?
      previous = tokens[index - 1]&.first&.upcase if index.positive?
      following = tokens[index + 1]&.first&.upcase

      line_break = nil
      if top
        if CLAUSES.include?(word)
          line_break = "\n"
          clause = word
        elsif JOIN_PREFIXES.include?(word) && %w[JOIN OUTER].include?(following)
          line_break = "\n"
          clause = "JOIN"
        elsif word == "JOIN" && !(JOIN_PREFIXES + %w[OUTER]).include?(previous)
          line_break = "\n"
          clause = "JOIN"
        elsif word == "BETWEEN"
          between = true
        elsif word == "AND" && between
          between = false
        elsif %w[AND OR].include?(word) && CONDITIONS.include?(clause)
          line_break = "\n  "
        end
      end

      if line_break
        out << line_break
      elsif space_before && !out.empty?
        out << " "
      end
      out << token

      case word
      when "(" then depth += 1
      when ")" then depth -= 1 if depth.positive?
      when "CASE" then case_depth += 1
      when "END" then case_depth -= 1 if case_depth.positive?
      end
    end

    out
  end
end
