# config/initializers/rack_attack.rb
# frozen_string_literal: true

class Rack::Attack
  # Redis 缓存（生产环境必须配置）
  if ENV["REDIS_URL"].present?
    Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV["REDIS_URL"])
  else
    # 没有 Redis 时使用内存缓存
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  # 白名单
  safelist('localhost') { |req| ['127.0.0.1', '::1'].include?(req.ip) }

  # 全局请求限流
  throttle('req/ip', limit: 40, period: 5.seconds) { |req| req.ip }

  # ==================== Devise Admin 保护 ====================

  # 登录保护
  throttle('admins/sign_in/ip', limit: 5, period: 1.minute) do |req|
    req.ip if req.path == '/admins/sign_in' && req.post?
  end

  # 注册保护（如果没开启 registerable 可删除）
  throttle('admins/sign_up/ip', limit: 3, period: 10.minutes) do |req|
    req.ip if req.path == '/admins/sign_up' && req.post?
  end

  # 注册保护（如果没开启 registerable 可删除）
  throttle('admins/ip', limit: 3, period: 10.minutes) do |req|
    req.ip if req.path == '/admins' && req.post?
  end

  # 密码重置保护
  throttle('admins/password/ip', limit: 5, period: 10.minutes) do |req|
    req.ip if req.path.match?(%r{^/admins/password}) && req.post?
  end

  # ==================== 挡扫描器 ====================
  blocklist('block scanners') do |req|
    req.path.match?(%r{
      wp-(admin|login|content|json)|
      phpmyadmin|
      \.env|\.git|xmlrpc\.php|
      administrator|config\.bak|backup
    }xi)
  end

  # 可疑 User-Agent
  blocklist('bad bots') do |req|
    req.user_agent&.match?(/bot|crawler|scrapy|nikto|masscan|python|curl|wget|httpie/i) &&
      !req.user_agent&.match?(/Googlebot|Bingbot|DuckDuckBot/i)
  end

  # 429 响应
  self.throttled_responder = lambda do |env|
    [429, { 'Content-Type' => 'application/json' },
     [{ error: "请求过于频繁，请稍后再试" }.to_json]]
  end
end
