class PostDigestJob < ApplicationJob
  queue_as :default

  def perform(limit: 5)
    # Find top posts
    top_posts = Post.published
                    .order(views_count: :desc)
                    .limit(limit)

    # Calculate statistics
    total_views = Post.published.sum(:views_count)
    avg_views = Post.published.average(:views_count)
    post_count = Post.published.count

    # Build digest
    {
      top_posts: top_posts.pluck(:id, :title, :views_count),
      stats: {
        total_views: total_views,
        average_views: avg_views,
        published_count: post_count
      }
    }
  end
end
