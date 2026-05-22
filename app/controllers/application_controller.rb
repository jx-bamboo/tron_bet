class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
  # include Pagy::Method
  # 直接封装官方示例的下注转账TRX方法
  def bet_transfer_trx(priv, amount)
    # puts ".... 链上转账 - 金额： #{amount} TRX ...."

    return false unless priv && amount
    # 直接复制你的原始代码，稍作封装
    trongrid_api_key = Rails.application.credentials.dig(:tron_grid_api_key)
    tronscan_api_key = Rails.application.credentials.dig(:tron_scan_api_key)
    # to_address = Rails.env.production? ? "TAMy8fj8ViqUjt6MZjtRaXDLLZubAsa47h" : "TDKHLgVPgmJmEBaDqmbELhfoYmcLBTukER"
    to_address = Rails.env.production? ? "TQrbuZYSeRMWiX9TbEy7C1SWX5bAQqrywc" : "TDKHLgVPgmJmEBaDqmbELhfoYmcLBTukER"

    key = Tron::Key.new(priv:)
    address = key.address

    client = Tron::Client.new(
      network: Rails.env.production? ? :mainnet : :shasta,
      api_key: trongrid_api_key,
      tronscan_api_key: tronscan_api_key
    )

    from_hex = Tron::Utils::Address.to_hex(address)
    to_hex = Tron::Utils::Address.to_hex(to_address)

    transaction = Tron::Utils::HTTP.post(
      "#{client.configuration.base_url}/wallet/createtransaction",
      {
        owner_address: from_hex,
        to_address: to_hex,
        amount: amount * 1_000_000  # 转换TRX到SUN
      }
    )

    tx_hash = Tron::Utils::Crypto.hex_to_bin(transaction["txID"])
    signature = key.sign(tx_hash)
    transaction["signature"] = [ signature ]

    result = Tron::Utils::HTTP.post(
      "#{client.configuration.base_url}/wallet/broadcasttransaction",
      transaction
    )

    # result = { "result" => true, "txid" => "6da288fd0ddbbd207ae0bb9dcc5fe9efd20048c2019ed28fcf00be619a61bc1a" }


    # 根据结果返回相应格式
    if result["result"] == true && result["txid"].present?
      Rails.logger.info ".... 转账成功 交易Hash:#{result["txid"]} ...."
      { success: true, transaction_id: result["txid"], raw_response: result }
    else
      Rails.logger.error ".... 转账失败:#{result["message"]} ...."
      { success: false, error: result["message"] || "转账交易失败", raw_response: result }
    end

  rescue => e
    { success: false, error: e.message }
  end

  def get_trx_balance(address)
    # url = URI("https://api.shasta.trongrid.io/wallet/getaccount")
    # url = URI("https://api.trongrid.io/wallet/getaccount")
    url = Rails.env.production? ? URI("https://api.trongrid.io/wallet/getaccount") : URI("https://api.shasta.trongrid.io/wallet/getaccount")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    # addr = "TGb2QdrSWZUSMgbps5WU97bReZLtn8xbBa"

    request = Net::HTTP::Post.new(url)
    request["accept"] = "application/json"
    request["content-type"] = "application/json"
    # request["TRON-PRO-API-KEY"] = ""
    request.body = { address:, visible: true }.to_json

    response = http.request(request)
    data = JSON.parse(response.read_body)
    balance_in_sun = data["balance"]
    balance_in_sun.to_f / 1_000_000
  end

  private
  def require_admin
    redirect_to root_path, notice: "权限不足" unless current_admin&.admin?
  end
end
