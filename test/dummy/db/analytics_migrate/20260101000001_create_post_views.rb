class CreatePostViews < ActiveRecord::Migration[8.0]
  def change
    create_table :post_views do |t|
      t.bigint :post_id, null: false, index: true
      t.string :user_agent
      t.string :ip_address
      t.string :referrer

      t.timestamps
    end

    add_index :post_views, :created_at
  end
end
