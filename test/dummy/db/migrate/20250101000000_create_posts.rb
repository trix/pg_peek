class CreatePosts < ActiveRecord::Migration[8.0]
  def change
    create_table :posts do |t|
      t.string :title, null: false
      t.text :body
      t.string :status, default: "draft"
      t.integer :views_count, default: 0
      t.timestamps
    end

    add_index :posts, :status
    add_index :posts, :created_at
  end
end
