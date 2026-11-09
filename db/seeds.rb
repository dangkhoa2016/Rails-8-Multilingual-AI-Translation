{
  "hy_mt2_30b" => "Tencent Hy-MT2-30B-A3B",
  "index_35b" => "Index-Translate-35B-A3B-preview",
  "gemma4_31b_it" => "Google Gemma 4 31B IT",
  "qwen35_35b" => "Qwen3.5-35B-A3B"
}.each_with_index do |(key, name), index|
  model = TranslationModel.find_or_initialize_by(model_key: key)
  model.assign_attributes(display_name: name, position: index)
  model.save!
end

if ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present?
  # Seeds only CREATE the initial admin; re-running db:seed must never reset
  # an existing administrator password to a stale environment value.
  if User.exists?(email: ENV.fetch("ADMIN_EMAIL").strip.downcase)
    puts "Existing administrator retained; password was not changed"
  else
    User.create!(email: ENV.fetch("ADMIN_EMAIL"), password: ENV.fetch("ADMIN_PASSWORD"), role: "admin")
    puts "Initial administrator created"
  end
else
  puts "Admin not seeded: set ADMIN_EMAIL and ADMIN_PASSWORD when running db:seed"
end
