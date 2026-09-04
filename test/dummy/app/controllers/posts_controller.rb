# Endpoint traffic for pg_peek to attribute. #index issues a deliberate N+1 so
# the queries-per-request heuristic has something real to detect; #show issues
# one query per request as a control.
class PostsController < ApplicationController
  def index
    @posts = Post.order(:id).limit(10)
    @related = @posts.map { |post| Post.where.not(id: post.id).limit(1).to_a }

    render plain: "#{@posts.size} posts"
  end

  def show
    @post = Post.find(params[:id])

    render plain: @post.title
  end
end
