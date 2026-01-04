module PgPeek
  class QueryLoader
    class << self
      def load(path, pg_version:, **variables)
        sql = read_file(path, pg_version)
        interpolate(sql, variables)
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
