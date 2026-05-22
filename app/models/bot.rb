class Bot < ApplicationRecord
  belongs_to :member
  has_many :bet_records, dependent: :destroy

  enum :status, [ :stopped, :running, :waiting_result, :paused ]
  enum :current_parity, [ :double, :single ]

  # DOUBLE_AMOUNTS = [ 6, 12, 24, 50, 106, 230, 486, 1102, 2352, 4902 ].freeze
  # SINGLE_AMOUNTS = [ 5, 11, 23, 49, 105, 229, 485, 1101, 2351, 4901 ].freeze
  DOUBLE_AMOUNTS = [ 10, 20, 44, 98, 206, 456, 960, 1998 ].freeze
  SINGLE_AMOUNTS = [ 11, 21, 47, 101, 213, 475, 981, 2021 ].freeze

  # 处理新的区块记录（由 BlockMonitorJob 调用）
  def process_new_block(latest_block)
    return false unless running? || waiting_result?

    check_bet_result
    check_for_new_bet
  end

  # 核心监控方法
  def check_for_new_bet
    # 新增：检查是否有未结算的下注
    if bet_records.where(success: nil).exists?
      puts ".... 机器人 #{id} 还有未结算的下注，跳过新下单 ...."
      return false
    end

    check_count = get_strategy_for_count
    recent_records = BlockRecord.last(check_count) # 获取最新的区块记录

    # 检查区块是否连续
    unless blocks_consecutive?(recent_records.pluck(:number))
      puts Paint[".... 区块不连续，跳过 ....", :yellow]
      return false
    end

    puts Paint[".... Bot#{id} | Strategy: #{get_strategy_text_log} | Current Streak: #{calculate_current_streak_length(recent_records.map(&:parity))} ....", :blue]
    analyze_and_process(recent_records, check_count) # 分析连续情况
  end

  def check_bet_result
    # 获取最新的下注记录
    last_bet = bet_records.where(success: nil).last
    return false unless last_bet

    next_block = BlockRecord.find(last_bet.block_record_id + 1)

    # 检查结果 - 注意：现在BetRecord的enum有前缀，我们需要使用数值比较
    bet_parity_value = last_bet.bet_parity_before_type_cast
    success = (bet_parity_value == next_block.parity)

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
      puts Paint[".... 💐💐💐 Nice one, 【#{member.username}】 Winner! 【₿ #{last_bet.bet_amount * 1.95}】 💐💐💐 ....", "#FFA500"]
      true
    else
      # 下注失败
      new_failed_times = failed_times + 1
      update!(failed_times: new_failed_times)

      # 检查是否达到止损，根据命数决定，如果10条命，那么 > 9
      if new_failed_times > 7
        update!(status: :paused)
        last_bet.update!(note: "Consecutive bet losses reached stop-loss limit")
        puts Paint[".... Bot#{id} | 【#{member.username}】 | Loss streak: #{new_failed_times}", :red]
      end
      puts Paint[".... 🧨 【#{member.username}】 Loss streak: #{new_failed_times} ....", :red]
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

  # 分析连续情况并处理
  def analyze_and_process(recent_records, check_count)
    return false if recent_records.length < check_count

    # 统一取最近的 parity 数组（从旧到新）
    parities = recent_records.map(&:parity)
    current_streak = calculate_current_streak_length(parities)

    # ================== zl5_8 特殊逻辑 ==================
    if strategy_type == "zl5_8"
      if current_streak >= 5 && current_streak <= 8
        execute_bet(recent_records.last, parities.last)
        puts Paint[".... 🐉【#{member.username}】 zl5_8 砍龙中 | 连续 #{current_streak} 个 ....", :magenta]
        return true
      elsif current_streak > 8
        puts Paint[".... 🛑【#{member.username}】 zl5_8 连续 #{current_streak} > 8，停止砍龙 ....", :red]
        return false
      else
        return false  # 连续 < 5，不下注
      end
    end

    # ================== 其他策略（zl2/zl3/zl4）保持原有逻辑 ==================
    check_blocks = recent_records.first(check_count)
    parities_for_check = check_blocks.map(&:parity)

    # 原有的长龙保护（count+1 全相同则不砍）
    long_blocks = BlockRecord.last(check_count + 1)
    if long_blocks.map(&:parity).uniq.length == 1
      puts Paint[".... 🐉 【#{member.username}】 Long streak: no chop ....", :red]
      return false
    end

    if parities_for_check.uniq.length == 1
      execute_bet(check_blocks.last, parities_for_check.last)
      true
    else
      false
    end
  end

  # 分析连续情况并处理（没有zl5_8这种可以直接上）
  # def analyze_and_process(recent_records, check_count)
  #   # 获取需要检查的区块
  #   check_blocks = recent_records.first(check_count)
  #   return false if check_blocks.length < check_count

  #   # 检查是否全部相同，使用uniq去重，如果所有值相同则parities长度为1
  #   parities = check_blocks.map(&:parity).uniq

  #   long_blocks = BlockRecord.last(check_count + 1)
  #   if long_blocks.map(&:parity).uniq.length == 1
  #     puts Paint[".... 🐉 【#{member.username}】 Long streak: no chop ....", :red]
  #     return false
  #   end

  #   if parities.length == 1
  #     execute_bet(check_blocks.last, parities.first) # 参数（最后一个区块， 最后一个单双结果）连续相同结果，执行反向下注
  #     true
  #   else
  #     # puts Paint[".... Not match ....", :yellow]
  #     false
  #   end
  # end

  # 执行下注, streak_parity 当前连续出现的单双结果，
  def execute_bet(block_record, streak_parity)
    bet_parity = streak_parity == 1 ? 0 : 1  # 反向下注； 1是单，0是双； bet_parity就是要下注的方向

    bet_amount = calculate_bet_amount(bet_parity) # 计算下注金额，这里需要添加失败计算次数

    # 创建下注记录
    bet_record = bet_records.create!(
      block_record: block_record,
      bet_parity: bet_parity, # 下注方向
      bet_amount: bet_amount, # 下注金额
      status: :pending
    )

    puts Paint[".... Bot##{id} | Strategy: #{get_strategy_text_log} | Bet: #{bet_amount}TRX | Side: #{bet_record.bet_parity_text} ....", :cyan]

    # 执行转账
    if transfer_trx(bet_amount, bet_record)
      # 进入等待结果状态
      update!(
        status: :waiting_result,
        current_parity: streak_parity, # 当前的连续结果，不是下注结果
        bet_amount_index: bet_amount
      )

      puts Paint[".... 💸💸💸 【#{member.username}】 Bet placed 💸💸💸 ....", :green]
      true
    else
      # 转账失败
      # bet_record.update!(
      #   success: false,
      #   note: "转账失败",
      #   status: :failed

      # )
      p ".... 下注执行失败 - 下注ID: #{bet_record.id} ...."
      false
    end
  end

  # 计算下注金额 - 这是核心逻辑
  # bet_parity 就是要下注的方向，金额找相对应的方向数组（以第一个数组元素为基准）
  def calculate_bet_amount(bet_parity)
    return nil if failed_times < 0 || failed_times > 9
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

  # 转账方法 - 调用您在ApplicationController中封装的方法
  def transfer_trx(amount, bet_record)
    # 这里调用您在ApplicationController中封装的方法
    result = ApplicationController.new.bet_transfer_trx(member.tron_private_key, amount)

    if result[:success]
      bet_record.update!(transaction_id: result[:transaction_id], status: :completed)

      # 记录交易日志
      # member.transaction_logs.create!(
      #   transaction_type: "bet",
      #   amount: amount,
      #   transaction_hash: result[:transaction_id],
      #   status: "success",
      #   block_record: bet_record.block_record,
      #   raw_data: result
      # )

      true
    else
      p ".... 转账失败 - 机器人: #{id}, 金额: #{amount} TRX, 错误: #{result[:error] || '未知错误'} ...."
      bet_record.update!(transaction_id: result[:error], status: "failed")
      # 记录失败的交易日志
      # member.transaction_logs.create!(
      #   transaction_type: "bet",
      #   amount: amount,
      #   status: "failed",
      #   block_record: bet_record.block_record,
      #   raw_data: { error: result[:error] }
      # )
      bet_record.destroy!


      false
    end
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
    when "zl5_8"
      "ChopStreak(5_8)"
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
    when "zl5_8"
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
  end
end
