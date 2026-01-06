class PostPublishJob < ApplicationJob
  queue_as :default

  def perform(post_id)
    post = Post.find(post_id)
    return if post.status == "published"

    post.update!(status: "published")

    # Log related posts for cross-promotion
    Post.published
        .where.not(id: post.id)
        .order(views_count: :desc)
        .limit(5)
        .pluck(:id, :title)
  end
end
