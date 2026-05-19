class BlockRecord < ApplicationRecord
  validates :number, :block_hash, presence: true, uniqueness: true

  def self.recent_with_groups(limit: 200)
    records = order(block_time: :desc).limit(limit).to_a

    groups = []
    current_group = []

    records.each_with_index do |record, index|
      result = record.parity == 1 ? "单" : "双"
      color  = result == "单" ? "#ff3636ff" : "#24b3a2ff"
      item = { result:, color: }

      if index > 0
        prev = records[index - 1]
        if (prev.block_time - record.block_time) > 60.seconds
          groups << current_group if current_group.any?
          groups << []
          current_group = []
        end
      end

      if current_group.empty? || current_group.last[:result] == result
        current_group << item
      else
        groups << current_group
        current_group = [ item ]
      end
    end

    groups << current_group if current_group.any?

    { records: records, groups: groups }
  end

  # 检查是否连续
  def self.consecutive?(records)
    return true if records.length <= 1

    records.each_cons(2).all? do |a, b|
      (b.number.to_i - a.number.to_i) == 20
    end
  end

  # 获取最新的连续区块
  def self.recent_consecutive(count = 10)
    records = recent.limit(count * 2).order(number: :asc)

    # 从最新开始找连续的区块
    consecutive_records = []
    last_num = nil

    records.reverse.each do |record|
      if last_num.nil? || (last_num.to_i - record.number.to_i) == 20
        consecutive_records.unshift(record)
        last_num = record.number
      else
        break
      end

      break if consecutive_records.length >= count
    end

    consecutive_records
  end
end
