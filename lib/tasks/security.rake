namespace :security do
  desc "Remove expired login rate-limit counters (run from a scheduled maintenance job)"
  task prune_login_throttles: :environment do
    cutoff = 1.day.ago
    removed = 0
    loop do
      keys = LoginThrottle.where(expires_at: ...cutoff).limit(1_000).pluck(:key)
      break if keys.empty?
      removed += LoginThrottle.where(key: keys).delete_all
    end
    puts "Removed #{removed} expired throttle counters"
  end
end
