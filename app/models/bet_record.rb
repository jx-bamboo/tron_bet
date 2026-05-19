class BetRecord < ApplicationRecord
  belongs_to :bot
  belongs_to :block_record

  validates :bet_amount, numericality: { greater_than: 0 }
  validates :bot_id, uniqueness: { scope: :block_record_id, message: "该期已下注" }

  enum :bet_parity, [ :double, :single ], prefix: true
  enum :result_parity, [ :double, :single ], prefix: true
  enum :status, [ :pending, :completed, :failed ] # 转账状态

  delegate :parity, to: :block_record
  delegate :number, to: :block_record

  def parity_text(parity_value)
    parity_value == 0 ? "双" : "单"
  end

  def bet_parity_text
    case bet_parity
    when "double"
      "Even"
    when "single"
      "Odd"
    else
      "none"
    end
  end

  def result_parity_text
    return "等待" if result_parity.nil?

    case result_parity
    when "double"
      "双"
    when "single"
      "单"
    else
      "未知"
    end
  end


  def result_text
    return "等待结果" if success.nil?
    success ? "成功" : "失败"
  end

  def status_class
    return "warning" if success.nil?
    success ? "success" : "danger"
  end

  # 用于在查询时使用原始值
  def self.bet_parities
    { double: 0, single: 1 }
  end

  def self.result_parities
    { double: 0, single: 1 }
  end
end
