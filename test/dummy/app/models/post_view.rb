class PostView < AnalyticsRecord
  # post_id references Post in primary database (cross-database relation)
  # We can't use belongs_to across databases, so we use a manual lookup

  validates :post_id, presence: true

  scope :for_post, ->(post_id) { where(post_id: post_id) }
  scope :recent, -> { where("created_at > ?", 24.hours.ago) }

  def post
    Post.find_by(id: post_id)
  end
end
