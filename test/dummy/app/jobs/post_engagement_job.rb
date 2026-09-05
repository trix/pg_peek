class PostEngagementJob < ApplicationJob
  queue_as :default

  def perform(post_id = nil)
    if post_id
      analyze_single_post(post_id)
    else
      analyze_all_posts
    end
  end

  private

  def analyze_single_post(post_id)
    # Query primary database for post
    post = Post.find(post_id)

    # Query analytics database for views
    views_count = PostView.for_post(post_id).count
    recent_views = PostView.for_post(post_id).recent.count

    # More analytics queries
    PostView.for_post(post_id).group("DATE(created_at)").count
    PostView.for_post(post_id).where.not(referrer: nil).distinct.pluck(:referrer)

    {
      post: post.title,
      total_views: views_count,
      recent_views: recent_views
    }
  end

  def analyze_all_posts
    # Query primary database
    posts = Post.published.order(views_count: :desc).limit(10)
    post_ids = posts.pluck(:id)

    # Query analytics database
    total_views = PostView.count
    views_by_post = PostView.where(post_id: post_ids).group(:post_id).count
    recent_activity = PostView.recent.group(:post_id).count

    # Cross-reference: find posts with most engagement
    top_referrers = PostView.where.not(referrer: nil)
                            .group(:referrer)
                            .order(Arel.sql("count(*) DESC"))
                            .limit(5)
                            .count

    {
      total_tracked_views: total_views,
      views_by_post: views_by_post,
      recent_activity: recent_activity,
      top_referrers: top_referrers
    }
  end
end
