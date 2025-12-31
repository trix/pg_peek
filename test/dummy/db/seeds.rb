puts "Seeding posts..."

10.times do |i|
  Post.create!(
    title: "Post #{i + 1}",
    body: "This is the body of post #{i + 1}. " * 10,
    status: %w[draft published archived].sample,
    views_count: rand(0..1000)
  )
end

puts "Created #{Post.count} posts"
