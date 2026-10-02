puts "Seeding posts..."

20.times do |i|
  Post.create!(
    title: "Post #{i + 1}",
    body: "This is the body of post #{i + 1}. " * 10,
    status: %w[draft published archived].sample,
    views_count: rand(0..1000)
  )
end

puts "Created #{Post.count} posts"

puts "\nSeeding post views (analytics database)..."

referrers = [
  "https://google.com/search?q=rails",
  "https://twitter.com/post/123",
  "https://news.ycombinator.com/item?id=456",
  "https://reddit.com/r/rails",
  nil
]

user_agents = [
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
  "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)",
  "Mozilla/5.0 (Linux; Android 11)"
]

Post.published.each do |post|
  rand(5..50).times do
    PostView.create!(
      post_id: post.id,
      user_agent: user_agents.sample,
      ip_address: "#{rand(1..255)}.#{rand(1..255)}.#{rand(1..255)}.#{rand(1..255)}",
      referrer: referrers.sample,
      created_at: rand(30).days.ago + rand(24 * 60).minutes
    )
  end
end

puts "Created #{PostView.count} post views"

puts "\nRunning example jobs to generate pg_stat_statements data..."

# Jobs that query primary database only
puts "  Running PostAnalyticsJob (all posts)..."
PostAnalyticsJob.perform_now

puts "  Running PostAnalyticsJob (per post)..."
Post.limit(5).each do |post|
  PostAnalyticsJob.perform_now(post.id)
end

puts "  Running PostPublishJob..."
Post.draft.limit(3).each do |post|
  PostPublishJob.perform_now(post.id)
end

puts "  Running PostCleanupJob..."
PostCleanupJob.perform_now

puts "  Running PostDigestJob..."
3.times { PostDigestJob.perform_now(limit: 5) }

puts "  Running Reports::PostSummaryJob..."
Reports::PostSummaryJob.perform_now

# Jobs that query BOTH databases (primary + analytics)
puts "  Running PostEngagementJob (all posts - queries both databases)..."
PostEngagementJob.perform_now

puts "  Running PostEngagementJob (per post - queries both databases)..."
Post.published.limit(5).each do |post|
  PostEngagementJob.perform_now(post.id)
end

puts "\nDone! Jobs have generated queries in pg_stat_statements."
puts "Visit /pg_peek/jobs to see the dashboard."
puts "\nPostEngagementJob queries both 'primary' and 'analytics' databases."
