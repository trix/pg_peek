module PgPeek
  class QueryLoader
    # Every statement pg_peek issues ends with this, so the statistics queries
    # can leave the engine's own cost out of what they report. It has to be a
    # trailing comment: pg_stat_statements stores a statement from its first
    # token, so a leading comment is dropped, while trailing text is kept --
    # which is also why Rails' SQLcommenter tags survive.
    MARKER = "/* pg_peek */".freeze

    class << self
      def load(path, pg_version:, **variables)
        sql = read_file(path, pg_version)
        mark(interpolate(sql, variables))
      end

      def mark(sql)
        # Only a marker at the end counts: the statistics queries mention the
        # marker inside their own exclusion filter.
        return sql if sql.rstrip.end_with?(MARKER)

        # A trailing semicolon would end the statement before the comment.
        "#{sql.rstrip.chomp(";")} #{MARKER}"
      end

      private

      def read_file(path, pg_version)
        full_path = Engine.root.join("app/queries/pg_peek", "pg#{pg_version}", "#{path}.sql")

        if Rails.env.production?
          cache[full_path] ||= File.read(full_path)
        else
          File.read(full_path)
        end
      end

      def cache
        @cache ||= {}
      end

      def interpolate(sql, variables)
        result = sql.dup

        # Handle {{placeholders:key}} - expands to $1, $2, ..., $n
        result = result.gsub(/\{\{placeholders:(\w+)\}\}/) do
          count = variables[::Regexp.last_match(1).to_sym].to_i
          (1..count).map { |i| "$#{i}" }.join(", ")
        end

        # Handle simple {{key}} replacements
        variables.each do |key, value|
          result = result.gsub("{{#{key}}}", value.to_s)
        end

        result
      end
    end
  end
end
