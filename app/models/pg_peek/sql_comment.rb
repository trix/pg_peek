# Parses the trailing SQLcommenter comment Rails' query_log_tags appends to a
# query -- e.g. /*action='index',application='Dummy',controller='posts'*/ --
# and reduces it to the one thing worth showing at a glance: what issued this
# query. Used by both the Sessions report and the view layer, so there is one
# parser rather than the two that used to disagree on how tags are shaped.
class PgPeek::SqlComment
  TAG = /(\w+)='([^']*)'/

  def self.tags(query)
    comment = query.to_s[%r{/\*([^*]*=[^*]*)\*/}, 1] or return {}
    comment.scan(TAG).to_h { |key, value| [ key, CGI.unescape(value) ] }
  end

  # A job always names itself. Otherwise, the endpoint that issued this, if
  # SQLcommenter tagged it. Otherwise nil -- callers fall back to whatever
  # else identifies the source (an application_name, or nothing).
  def self.label(tags)
    return tags["job"] if tags["job"].present?

    controller = tags["namespaced_controller"] || tags["controller"]
    return nil if controller.blank?

    [ controller, tags["action"] ].compact_blank.join("#")
  end
end
