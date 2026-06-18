class Bot < ApplicationRecord
  belongs_to :member
  has_many :bet_records, dependent: :destroy

  enum :status, [ :stopped, :running, :waiting_result, :paused ]
  enum :current_parity, [ :double, :single ]

  # DOUBLE_AMOUNTS = [ 6, 12, 24, 50, 106, 230, 486, 1102, 2352, 4902 ].freeze
  # SINGLE_AMOUNTS = [ 5, 11, 23, 49, 105, 229, 485, 1101, 2351, 4901 ].freeze
  DOUBLE_AMOUNTS = [ 10, 20, 44, 98, 206, 456, 960, 1998 ].freeze
  SINGLE_AMOUNTS = [ 11, 21, 47, 101, 213, 475, 981, 2021 ].freeze

  # BlockMonitorJob 保存区块后调用
  def process_new_block(latest_block)
    return false unless running? || waiting_result?
    check_the_betting_result
    check_if_to_place_a_bet
  end

  def check_if_to_place_a_bet
    # 检查是否有未标记结果的投注
    if bet_records.where(success: nil).exists?
      logger.info ".... 机器人 #{id} 还有未结算的下注，跳过新下单 ...."
      return false
    end

    check_count = case strategy_type
                  when "zl7_9"
                    get_strategy_count_for_zl7_9
                  when "zl5_8"
                    get_strategy_count_for_zl5_8
                  when "zl2_3"
                    get_strategy_count_for_zl2_3
                  when "zl2_3_m"
                    get_zl2_3_m
                  when "zl3_4_m"
                    get_zl3_4_m
                  else
                    get_strategy_for_count
                  end

    recent_records = BlockRecord.last(check_count) # 根据砍龙数量，获取最新的区块记录
    return false if recent_records.length < check_count

    # 检查最新区块编号是否连续且没有断档
    unless blocks_consecutive?(recent_records.pluck(:number))
      logger.info Paint[".... 区块不连续，跳过 ....", :yellow]
      return false
    end
    return false unless long_streak_stop_chopping(check_count)

    # puts Paint[".... Bot#{id} | Strategy: #{get_strategy_text_log} | Current Streak: #{calculate_current_streak_length(recent_records.map(&:parity))} ....", :blue]
    analyze_and_process(recent_records, check_count) # 分析数据并决定是否投注
  end

  def check_the_betting_result
    # 获取最新的下注记录
    last_bet = bet_records.where(success: nil).last
    return false unless last_bet

    next_block = BlockRecord.find(last_bet.block_record_id + 1)

    # 检查结果 - 注意：现在BetRecord的enum有前缀，我们需要使用数值比较
    bet_parity_value = last_bet.bet_parity_before_type_cast
    success = (bet_parity_value == next_block.parity) # 判断是否打中

    # 更新下注记录
    last_bet.update!(
      result_parity: next_block.parity,
      success: success
    )

    if success
      update!(
        status: :running,
        current_parity: nil,
        failed_times: 0,
        bet_amount_index: 0
      )
      last_bet.update!(note: "Winner")
      logger.info Paint[".... 💐💐💐 Nice one, 【#{member.username}】 Winner! 【₿ #{last_bet.bet_amount * 1.95}】 💐💐💐 ....", "#FFA500"]
      true
    else
      # 下注失败
      new_failed_times = failed_times + 1
      update!(failed_times: new_failed_times)

      # 检查是否达到止损，根据命数决定，如果10条命，那么 > 9
      if new_failed_times > 7
        update!(status: :paused)
        last_bet.update!(note: "Consecutive bet losses reached stop-loss limit")
        puts Paint[".... Bot#{id} | 【#{member.username}】 | Loss failed: #{new_failed_times}", :red]
      end
      logger.info Paint[".... 🧨 【#{member.username}】 Loss failed: #{new_failed_times} ....", :red]
      false
    end
  end

  # 赔率常量（与Member保持一致）
  BET_MULTIPLIER = 1.95

  # 计算机器人总盈利（修正版）
  def total_profit
    settled_bets = bet_records.where.not(success: nil)

    win_sum = settled_bets.where(success: true).sum(:bet_amount).to_f
    lose_sum = settled_bets.where(success: false).sum(:bet_amount).to_f
    total_wagered = win_sum + lose_sum

    # 修正算法：总盈利 = (赢的金额 × 1.95) - 总下注金额
    (win_sum * BET_MULTIPLIER) - total_wagered
  end

  # 计算机器人当日盈利（修正版）
  def today_profit
    today_bets = bet_records
      .where("DATE(created_at) = ?", Date.today)
      .where.not(success: nil)

    win_sum = today_bets.where(success: true).sum(:bet_amount).to_f
    lose_sum = today_bets.where(success: false).sum(:bet_amount).to_f
    total_wagered = win_sum + lose_sum

    (win_sum * BET_MULTIPLIER) - total_wagered
  end

  # 更新机器人停止时的盈利计算（修正版）
  def calculate_profit
    settled_bets = bet_records.where.not(success: nil)

    win_sum = settled_bets.where(success: true).sum(:bet_amount).to_f
    lose_sum = settled_bets.where(success: false).sum(:bet_amount).to_f
    total_wagered = win_sum + lose_sum

    (win_sum * BET_MULTIPLIER) - total_wagered
  end

  # 停止机器人时自动计算盈利
  def stop!
    profit_value = calculate_profit

    update!(
      status: :stopped,
      end_balance: member.get_current_balance,
      profit: profit_value,
      stopped_at: Time.current
    )
  end


  # ==================
  # 辅助方法：获取当前单双状态文本
  def current_parity_text
    return "" unless current_parity

    case current_parity
    when "double"
      "Even"
    when "single"
      "Odd"
    else
      ""
    end
  end
  # ==================

  private

  # 计算当前连续相同 parity 的长度（从最新往前数）
  def calculate_current_streak_length(parities)
    return 0 if parities.blank?

    last = parities.last
    streak = 1

    (parities.length - 2).downto(0) do |i|
      break if parities[i] != last
      streak += 1
    end

    streak
  end

  def analyze_and_process(recent_records, check_count)
    # 获取当前砍龙数量的区块
    check_blocks = recent_records.first(check_count)
    # 获取单双结果
    parities_for_check = check_blocks.map(&:parity)

    # 如果结果都一样，说明满足长龙要求
    if parities_for_check.uniq.size == 1
      execute_bet(check_blocks.last, parities_for_check.last)
    else
      return false
    end
  end

  # 超过策略的长龙不砍（最后 check_count + 1 个结果全部相同则不砍）
  def long_streak_stop_chopping(check_count)
    long_blocks = BlockRecord.last(check_count + 1)
    # 如果最后 check_count + 1 个 block 结果全部相同 → 不砍
    if long_blocks.map(&:parity).uniq.size == 1
      logger.info Paint[".... 🐉 【#{member.username}】 Long streak: Stop chopping ....", :red]
      false   # 不砍
    else
      true    # 可以砍
    end
  end


  # execute_bet 方法重构
  # streak_parity 出现的长龙方向
  def execute_bet(block_record, streak_parity)
    bet_parity = streak_parity == 1 ? 0 : 1
    if strategy_type == "zl2_3_m" || strategy_type == "zl3_4_m"
      bet_amount = failed_times.even? ? 50 : 100
    else
      bet_amount = calculate_bet_amount(bet_parity)
    end
    return false if bet_amount.nil?

    logger.info Paint[".... Bot##{id} | Strategy: #{get_strategy_text_log} | Bet: #{bet_amount}TRX | Side: #{bet_parity} ....", :cyan]
    # 直接入队，不在这里创建 BetRecord
    success = transfer_trx(bet_amount, block_record.id, bet_parity)

    if success
      update!(
        status: :waiting_result,
        current_parity: streak_parity,
        bet_amount_index: bet_amount
      )
      logger.info Paint[".... 💸💸💸 【#{member.username}】 Bet successful! 💸💸💸 ....", :green]
    else
      logger.error Paint[".... ❌ Bet failed! ....", :red]
      return false
    end
  end

  # 计算下注金额 - 这是核心逻辑
  # bet_parity 就是要下注的方向，金额找相对应的方向数组（以第一个数组元素为基准）
  def calculate_bet_amount(bet_parity)
    return nil if failed_times < 0 || failed_times > 7
    bet_parity == 1 ? SINGLE_AMOUNTS[failed_times] : DOUBLE_AMOUNTS[failed_times]
  end

  # 检查区块是否连续
  # block_numbers 是一个数组，包含连续的区块号 ["79268200", "79268220", "79268240"]
  # 如果每个数字之间的差值为20即是连续的
  # 返回 true 表示是连续的，false 表示不是连续的
  def blocks_consecutive?(block_numbers)
    block_integers = block_numbers.map(&:to_i)
    block_integers.each_cons(2).all? do |current, next_block|
      (next_block - current) == 20
    end
  end

  def transfer_trx(amount, block_record_id, bet_parity)
    TronTransferJob.perform_later(
      self.id,
      amount,
      block_record_id,
      bet_parity
    )
  rescue => e
    logger.error Paint[".... Bot #{id}: Tron transfer job failed: #{e.message} ....", :red]
    false
  end

  # 辅助方法：获取状态文本
  def status_text
    case status
    when "stopped"
      "已停止"
    when "running"
      "运行中"
    when "waiting_result"
      "等待结果"
    when "paused"
      "暂停中"
    else
      "未知"
    end
  end

  def get_strategy_text_log
    case strategy_type
    when "zl2"
      "ChopStreak(2)"
    when "zl3"
      "ChopStreak(3)"
    when "zl4"
      "ChopStreak(4)"
    when "zl5"
      "ChopStreak(5)"
    when "zl6"
      "ChopStreak(6)"
    when "zl7"
      "ChopStreak(7)"
    when "zl2_3"
      "ChopStreak(2_3)"
    when "zl5_8"
      "ChopStreak(5_8)"
    when "zl7_9"
      "ChopStreak(7_9)"
    when "zl2_3_m"
      "ChopStreak(2_3_m)"
    when "zl3_4_m"
      "ChopStreak(3_4_m)"
    end
  end

  def get_strategy_for_count
    case strategy_type
    when "zl2"
      2
    when "zl3"
      3
    when "zl4"
      4
    when "zl5"
      5
    when "zl6"
      6
    when "zl7"
      7
    end
  end

  def get_strategy_count_for_zl7_9
    case failed_times
    when 0
      7
    when 1
      8
    when 2
      9
    when 3
      7
    when 4
      8
    when 5
      9
    when 6
      7
    when 7
      8
    end
  end

  def get_strategy_count_for_zl5_8
    case failed_times
    when 0
      5
    when 1
      6
    when 2
      7
    when 3
      8
    when 4
      5
    when 5
      6
    when 6
      7
    when 7
      8
    end
  end

  def get_strategy_count_for_zl2_3
    case failed_times
    when 0
      2
    when 1
      3
    when 2
      2
    when 3
      3
    when 4
      2
    when 5
      3
    when 6
      2
    when 7
      3
    end
  end

  def get_zl2_3_m
    failed_times.even? ? 2 : 3
  end

  def get_zl3_4_m
    failed_times.even? ? 3 : 4
  end
end
