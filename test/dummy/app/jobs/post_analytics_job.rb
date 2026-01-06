class PostAnalyticsJob < ApplicationJob
  queue_as :default

  def perform(post_id = nil)
    if post_id
      post = Post.find(post_id)
      analyze_single(post)
    else
      analyze_all
    end
  end

  private

  def analyze_single(post)
    # Simulate analytics queries
    Post.where("views_count > ?", post.views_count).count
    Post.where(status: post.status).average(:views_count)
  end

  def analyze_all
    Post.published.order(views_count: :desc).limit(10).to_a
    Post.group(:status).count
    Post.group(:status).average(:views_count)
    Post.where("created_at > ?", 7.days.ago).count
  end
end
