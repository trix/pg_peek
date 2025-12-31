class Post < ApplicationRecord
  validates :title, presence: true

  scope :published, -> { where(status: "published") }
  scope :draft, -> { where(status: "draft") }
end
