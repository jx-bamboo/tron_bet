Tron.configure do |config|
  config.api_key = Rails.application.credentials.dig(:trongrid_api_key)
  config.network = Rails.env.production? ? :mainnet : :shasta
  config.timeout = 30
end
