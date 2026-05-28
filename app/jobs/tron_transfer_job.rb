# class TronTransferJob < ApplicationJob
#   queue_as :tron_transfers

#   # 生产重要：限制重试次数和间隔
#   retry_on StandardError, wait: :exponentially_longer, attempts: 4

#   def perform(bot_id, amount, bet_record_id)
#     bot = Bot.find(bot_id)
#     bet_record = BetRecord.find(bet_record_id)

#     to_address = Rails.env.production? ?
#       "TQrbuZYSeRMWiX9TbEy7C1SWX5bAQqrywc" :
#       "TDKHLgVPgmJmEBaDqmbELhfoYmcLBTukER"

#     result = TronTransferService.new.transfer(
#       bot.member.tron_private_key,
#       to_address,
#       amount,
#       bet_record_id
#     )

#     if result[:success]
#       bet_record.update!(
#         transaction_id: result[:transaction_id],
#         status: :completed,
#         completed_at: Time.current
#       )
#     else
#       bet_record.update!(status: :failed, note: result[:error])
#       Rails.logger.error ".... [Tron FAILED] Bot#{bot.id} | Error: #{result[:error]} ...."
#       puts ".... [Tron FAILED] Bot#{bot.id} | Error: #{result[:error]} ...."
#       raise ".... Transfer failed after retries ...." # 触发 Job 重试
#     end
#   end
# end
class TronTransferJob < ApplicationJob
  queue_as :tron_transfers

  retry_on StandardError, wait: :exponentially_longer, attempts: 4

  def perform(bot_id, amount, block_record_id, bet_parity)
    bot = Bot.find(bot_id)
    block_record = BlockRecord.find(block_record_id)
    to_address = Rails.env.production? ? "TQrbuZYSeRMWiX9TbEy7C1SWX5bAQqrywc" : "TDKHLgVPgmJmEBaDqmbELhfoYmcLBTukER"

    result = TronTransferService.new.transfer(
      bot.member.tron_private_key,
      to_address,
      amount
    )

    if result[:success]
      # 只有转账真正成功才创建记录
      bet_record = bot.bet_records.create!(
        block_record: block_record,
        bet_parity: bet_parity,
        bet_amount: amount,
        transaction_id: result[:transaction_id],
        status: :completed,
        success: nil   # 等待后续结果
      )

      Rails.logger.info ".... Bot #{bot.id} Transfer successful | Tx: #{result[:transaction_id]} ...."
    else
      Rails.logger.error ".... Bot #{bot.id} Transfer failed: #{result[:error]} ...."
      raise "Transfer failed"   # 触发 Job 重试
    end
  end
end
