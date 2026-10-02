# Namespaced on purpose: Rails url-encodes the job tag, so its name arrives in
# pg_stat_statements as Reports%3A%3APostSummaryJob.
class Reports::PostSummaryJob < ApplicationJob
  queue_as :default

  def perform
    Post.where("length(title) > ?", 0).maximum(:views_count)
  end
end
