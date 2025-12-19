module PgPeek
  module ApplicationHelper
    KNOWN_KEYS = %w[application controller namespaced_controller action job].freeze

    # example sql comment: /*action='show',application='Trmz',namespaced_controller='staff%2Fprocesses%2Fprocesses'*/

    SQLCOMMENTER_PATTERN = %r{
      \s*                     # optional leading whitespace
      /\*                     # opening /*
      (?:                     # one or more key:value pairs
        [a-zA-Z_][a-zA-Z0-9_]*  # key (starts with letter/underscore)
        =                       # colon
        [^:*]*                  # value (anything except * or : to avoid breaking */
      \s*)+
      \*/                     # closing */
      \s*                     # optional trailing whitespace
    }xi

    def strip_sqlcommenter(sql)
      sql.gsub(SQLCOMMENTER_PATTERN, '').strip
    end

    def extract_comment(sql)
      comment_value = sql.scan(SQLCOMMENTER_PATTERN).first&.squish

      # strip opening and closing comment markers from the SQL comment
      comment_value&.gsub(/^\/\*/, '')&.gsub(/\*\/$/, '')
    end

    def sqlcommenter_to_hash(comment)
      comment.split(',').each_with_object({}) do |pair, hash|
        key, value = pair.split('=')
        hash[key] = value
      end
    end
  end
end
