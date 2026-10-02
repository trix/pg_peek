# Namespaced on purpose: Rails url-encodes the namespaced_controller tag
# (admin%2Fposts), and the controller tag reads posts, the same as
# PostsController's. The query is one no other code issues, because
# pg_stat_statements keeps the tags of the first query of each shape.
class Admin::PostsController < ApplicationController
  def index
    count = Post.where("position(? in title) >= 0", "a").count

    render plain: "#{count} posts"
  end
end
