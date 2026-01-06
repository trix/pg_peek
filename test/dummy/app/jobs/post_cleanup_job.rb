class PostCleanupJob < ApplicationJob
  queue_as :low

  def perform
    # Find posts that should be archived
    stale_drafts = Post.draft.where("updated_at < ?", 30.days.ago)
    stale_count = stale_drafts.count

    stale_drafts.find_each do |post|
      post.update!(status: "archived")
    end

    # Report on archived posts
    Post.where(status: "archived").count
    Post.where(status: "archived").sum(:views_count)

    stale_count
  end
end
