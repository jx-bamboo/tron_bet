class TronTransferService
  CONCURRENT_LIMIT = 8
  MAX_RETRIES = 5

  @@semaphore = Concurrent::Semaphore.new(CONCURRENT_LIMIT)

  def transfer(from_private_key, to_address, amount_in_trx)
    @@semaphore.acquire

    retries = 0
    begin
      key = Tron::Key.new(priv: from_private_key)
      from_address = key.address
      amount_sun = (amount_in_trx * 1_000_000).to_i

      # 使用全局配置的 base_url（gem 推荐方式）
      base_url = Tron.configuration.base_url

      # 创建交易
      transaction = Tron::Utils::HTTP.post(
        "#{base_url}/wallet/createtransaction",
        {
          owner_address: Tron::Utils::Address.to_hex(from_address),
          to_address: Tron::Utils::Address.to_hex(to_address),
          amount: amount_sun
        }
      )

      # 本地签名
      tx_hash = Tron::Utils::Crypto.hex_to_bin(transaction["txID"])
      signature = key.sign(tx_hash)
      transaction["signature"] = [signature]

      # 广播交易
      result = Tron::Utils::HTTP.post(
        "#{base_url}/wallet/broadcasttransaction",
        transaction
      )

      if result["result"] == true && result["txid"].present?
        { success: true, transaction_id: result["txid"], raw: result }
      else
        { success: false, error: result["message"] || "广播失败" }
      end

    rescue => e
      if should_retry?(e) && retries < MAX_RETRIES
        retries += 1
        sleep calculate_backoff(retries)
        retry
      else
        { success: false, error: e.message, retries: retries }
      end
    ensure
      @@semaphore.release
    end
  end

  private

  def should_retry?(error)
    msg = error.message.to_s.downcase
    msg.include?("rate") || msg.include?("429") || msg.include?("503") ||
    msg.include?("timeout") || msg.include?("busy") || msg.include?("exceeded")
  end

  def calculate_backoff(retries)
    (2 ** retries) * 0.4 + rand(0.3..0.8)
  end
end
