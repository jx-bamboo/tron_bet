class Member < ApplicationRecord
  validates :username, :tron_address, :tron_private_key, :strategy, presence: true
  validates :tron_address, :tron_private_key, uniqueness: true
  validates :strategy, inclusion: { in: [ "zl2", "zl3", "zl4", "zl5_8" ] }

  enum :status, [ :inactive, :active ]

  encrypts :tron_private_key

  has_one :bot, dependent: :destroy
  has_many :bet_records, through: :bot, dependent: :delete_all
  has_many :transaction_logs, dependent: :delete_all

  after_create :set_default_status

  def has_active_bot?
    bot && (bot.status == "running" || bot.status == "waiting_result")
  end

  def current_bot
    bot || create_bot
  end

  # 启动机器人
  def start_bot!
    return false, "机器人已在运行中" if has_active_bot?
    current_balance = get_current_balance

    if current_balance < 10
      return false, "余额不足10 TRX"
    end

    ActiveRecord::Base.transaction do
      # 创建或获取机器人
      bot_record = bot || create_bot

      # 启动机器人
      bot_record.update!(
        status: :running, # 运行中
        strategy_type: strategy, # 策略类型
        bet_amount_index: 0,
        start_balance: current_balance,
        started_at: Time.current
      )

      # 更新会员状态
      update!(status: :active, active: true)

      p ".... 🔉 机器人启动 - 会员: #{id}, 策略: #{strategy}, 开始余额: #{current_balance} ...."
      # 立即检查是否需要下注
      bot_record.check_for_new_bet
    end

    [ true, "机器人启动成功" ]
  rescue => e
    Rails.logger.error "启动机器人失败 - 会员: #{id}, 错误: #{e.message}"
    [ false, "启动失败: #{e.message}" ]
  end

  # 停止机器人
  def stop_bot!
    return false, "没有运行的机器人" if bot.status == "stopped"
    return false, "有需要亏损的订单" if (1..9).include?(bot.failed_times)

    ActiveRecord::Base.transaction do
      # 获取当前余额
      current_balance = get_current_balance

      # 计算盈利
      profit = (current_balance - bot.start_balance).round(6)

      # 停止机器人
      bot.update!(
        status: :stopped,
        failed_times: 0,
        end_balance: current_balance,
        profit: profit,
        stopped_at: Time.current
      )

      # 更新会员状态
      update!(status: :inactive, active: false)

      # 记录日志
      p "机器人停止 - 会员: #{id}, 结束余额: #{current_balance}, 盈利: #{profit}"
    end

    [ true, "机器人已停止" ]
  rescue => e
    Rails.logger.error "停止机器人失败 - 会员: #{id}, 错误: #{e.message}"
    [ false, "停止失败: #{e.message}" ]
  end

  # 机器人状态文本
  def bot_status_text
    return "未启动" unless bot

    bot.status_text
  end

  # 机器人状态对应的CSS类
  def bot_status_class
    case bot_status_text
    when "运行中" then "success"
    when "等待结果" then "warning"
    when "暂停中" then "danger"
    when "已停止" then "secondary"
    else "secondary"
    end
  end

  # ===================================================================
  # 赔率常量
  BET_MULTIPLIER = 1.95  # 赔率1.95倍
  BET_PROFIT_MULTIPLIER = 0.95  # 盈利倍数 (1.95 - 1)

  # 保本胜率 = 1 / (赔率) = 1 / 1.95 ≈ 51.28%
  # 因为: 胜率 × 1.95 > 1 时才盈利
  # 公式: 胜率 × 1.95 = 1 时盈亏平衡 => 胜率 = 1 / 1.95
  BREAK_EVEN_WIN_RATE = (1.0 / BET_MULTIPLIER * 100).round(2)  # 51.28%

  # 盈利计算核心方法（修正版）
  def calculate_profit_for_bets(bet_records_collection = nil)
    bets = bet_records_collection || bet_records
    settled_bets = bets.where.not(success: nil)

    # 计算成功和失败的总金额
    win_sum = settled_bets.where(success: true).sum(:bet_amount).to_f
    lose_sum = settled_bets.where(success: false).sum(:bet_amount).to_f
    total_wagered = win_sum + lose_sum  # 总下注金额

    # 修正算法：总收益 = 赢的金额 × 1.95，总盈利 = 总收益 - 总成本
    total_return = win_sum * BET_MULTIPLIER
    total_profit = total_return - total_wagered

    # 等价公式：总盈利 = 赢的金额 × 0.95 - 输的金额
    # total_profit = (win_sum * BET_PROFIT_MULTIPLIER) - lose_sum

    total_profit
  end

  # 计算当日盈利（修正版）
  def today_profit
    today_bets = bet_records
      .where("DATE(bet_records.created_at) = ?", Date.today)
      .where.not(success: nil)

    calculate_profit_for_bets(today_bets)
  end

  # 计算当日下注统计详情（修正版）
  def today_betting_stats
    today_bets = bet_records
      .where("bet_records.created_at >= ? AND bet_records.created_at < ?",
             Date.today.beginning_of_day, Date.tomorrow.beginning_of_day)
      .where.not(success: nil)
      .reorder(nil)                     # ← 重要

    generate_betting_stats(today_bets)
  end

  # 计算指定日期的盈利（新规则）
  def profit_on(date)
    bets = bet_records
      .where("DATE(bet_records.created_at) = ?", date)
      .where.not(success: nil)

    calculate_profit_for_bets(bets)
  end

  # 计算历史总盈利（新规则）
  def total_profit
    calculate_profit_for_bets(bet_records)
  end

  # 计算所有下注的详细统计（新规则）
  def betting_statistics
    all_bets = bet_records
      .where.not(success: nil)
      .reorder(nil)                     # ← 重要

    { all_time: generate_betting_stats(all_bets) }
  end

  # 获取盈利趋势（按天统计，修正版）
  # 计算盈利趋势（按天统计 - PostgreSQL 安全版）
  def daily_profit_trend(days: 30)
    end_date = Date.today
    start_date = end_date - (days - 1).days

    daily_stats = bet_records
      .where("bet_records.created_at >= ? AND bet_records.created_at <= ?",
             start_date.beginning_of_day, end_date.end_of_day)
      .where.not(success: nil)
      .group("DATE(bet_records.created_at)")
      .select(
        "DATE(bet_records.created_at) AS bet_date",
        "COUNT(*) AS total_bets",
        "SUM(CASE WHEN success = true THEN 1 ELSE 0 END) AS win_bets",
        "SUM(CASE WHEN success = false THEN 1 ELSE 0 END) AS lose_bets",
        "SUM(CASE WHEN success = true THEN bet_amount ELSE 0 END) AS win_amount",
        "SUM(CASE WHEN success = false THEN bet_amount ELSE 0 END) AS lose_amount",
        "MAX(bet_records.id) AS max_id",           # 解决 id 报错
        "MAX(bet_records.created_at) AS max_time"  # 用于排序
      )
      .order("bet_date DESC")   # 必须用分组后的列排序
      .limit(days)

    # 转换为前端友好格式
    daily_stats.map do |stat|
      win_sum = stat.win_amount.to_f
      lose_sum = stat.lose_amount.to_f
      total_wagered = win_sum + lose_sum

      daily_profit = (win_sum * BET_MULTIPLIER) - total_wagered

      {
        date: stat.bet_date,
        total_bets: stat.total_bets.to_i,
        win_bets: stat.win_bets.to_i,
        lose_bets: stat.lose_bets.to_i,
        win_rate: stat.total_bets > 0 ? (stat.win_bets.to_f / stat.total_bets * 100).round(2) : 0,
        total_profit: daily_profit.round(6),
        win_total_amount: win_sum,
        lose_total_amount: lose_sum,
        total_wagered: total_wagered
      }
    end
  end

  # 计算单日统计详情（修正版）
  def daily_stats_on(date)
    bets = bet_records
      .where("DATE(bet_records.created_at) = ?", date)
      .where.not(success: nil)

    generate_betting_stats(bets, include_date: true, date: date)
  end

  # 计算时间段内的盈利报告（修正版）
  def profit_report(start_date, end_date)
    bets = bet_records
      .where(bet_records: { created_at: start_date.beginning_of_day..end_date.end_of_day })
      .where.not(success: nil)

    generate_detailed_report(bets, start_date, end_date)
  end

  private

  def set_default_status
    self.status ||= :inactive
    self.active = (status == "active")
  end

  def get_current_balance
    p ".... 地址： #{tron_address} ...."
    begin
      ApplicationController.new.get_trx_balance(tron_address)
    rescue => e
      p ".... 获取余额失败 - 会员: #{id}, 错误: #{e.message} ...."
      0
    end
  end

  # 生成下注统计数据（修正版）
  # def generate_betting_stats(bets, include_date: false, date: nil)
  #   win_bets = bets.where(success: true)
  #   lose_bets = bets.where(success: false)

  #   win_sum = win_bets.sum(:bet_amount).to_f
  #   lose_sum = lose_bets.sum(:bet_amount).to_f
  #   total_wagered = win_sum + lose_sum

  #   # 修正算法：总盈利 = (赢的金额 × 1.95) - 总下注金额
  #   total_profit = (win_sum * BET_MULTIPLIER) - total_wagered

  #   stats = {
  #     total_bets: bets.count,
  #     win_bets: win_bets.count,
  #     lose_bets: lose_bets.count,
  #     win_rate: bets.count > 0 ?
  #       (win_bets.count.to_f / bets.count * 100).round(2) : 0,
  #     total_profit: total_profit.round(6),
  #     win_total_amount: win_sum,
  #     lose_total_amount: lose_sum,
  #     total_wagered: total_wagered,
  #     total_return: (win_sum * BET_MULTIPLIER).round(6),
  #     # 投资回报率 = 总盈利 / 总下注金额
  #     roi: total_wagered > 0 ?
  #       (total_profit / total_wagered * 100).round(2) : 0,
  #     # 盈亏平衡所需胜率 = 1 / 赔率
  #     break_even_win_rate: BREAK_EVEN_WIN_RATE
  #   }

  #   if include_date
  #     stats[:date] = date
  #     stats[:avg_bet_amount] = bets.count > 0 ? (total_wagered / bets.count).to_f : 0
  #   end

  #   stats
  # end
  def generate_betting_stats(bets, include_date: false, date: nil)
    # 关键修复：彻底清除默认 ORDER BY + 只做聚合
    stats_data = bets
      .reorder(nil)                    # 清除 bet_records.id 的默认排序
      .select(
        "COUNT(*) as total_bets",
        "SUM(CASE WHEN success = true THEN 1 ELSE 0 END) as win_count",
        "SUM(CASE WHEN success = false THEN 1 ELSE 0 END) as lose_count",
        "COALESCE(SUM(CASE WHEN success = true THEN bet_amount ELSE 0 END), 0) as win_sum",
        "COALESCE(SUM(CASE WHEN success = false THEN bet_amount ELSE 0 END), 0) as lose_sum",
        "COALESCE(SUM(bet_amount), 0) as total_wagered"
      ).first

    return {
      total_bets: 0, win_bets: 0, lose_bets: 0,
      win_rate: 0, total_profit: 0, win_total_amount: 0,
      lose_total_amount: 0, total_wagered: 0,
      total_return: 0, roi: 0,
      break_even_win_rate: BREAK_EVEN_WIN_RATE
    } if stats_data.nil?

    total_bets = stats_data.total_bets.to_i
    win_count = stats_data.win_count.to_i
    lose_count = stats_data.lose_count.to_i
    win_sum = stats_data.win_sum.to_f
    lose_sum = stats_data.lose_sum.to_f
    total_wagered = stats_data.total_wagered.to_f

    total_profit = (win_sum * BET_MULTIPLIER) - total_wagered
    win_rate = total_bets > 0 ? (win_count.to_f / total_bets * 100).round(2) : 0
    roi = total_wagered > 0 ? (total_profit / total_wagered * 100).round(2) : 0

    stats = {
      total_bets: total_bets,
      win_bets: win_count,
      lose_bets: lose_count,
      win_rate: win_rate,
      total_profit: total_profit.round(6),
      win_total_amount: win_sum,
      lose_total_amount: lose_sum,
      total_wagered: total_wagered,
      total_return: (win_sum * BET_MULTIPLIER).round(6),
      roi: roi,
      break_even_win_rate: BREAK_EVEN_WIN_RATE
    }

    if include_date
      stats[:date] = date
      stats[:avg_bet_amount] = total_bets > 0 ? (total_wagered / total_bets).round(6) : 0
    end

    stats
  end

  # 生成详细盈利报告（修正版）
  def generate_detailed_report(bets, start_date, end_date)
    settled_bets = bets.where.not(success: nil)

    win_bets = settled_bets.where(success: true)
    lose_bets = settled_bets.where(success: false)

    win_count = win_bets.count
    lose_count = lose_bets.count
    total_count = settled_bets.count

    win_sum = win_bets.sum(:bet_amount).to_f
    lose_sum = lose_bets.sum(:bet_amount).to_f
    total_wagered = win_sum + lose_sum

    # 修正算法
    total_profit = (win_sum * BET_MULTIPLIER) - total_wagered
    total_return = win_sum * BET_MULTIPLIER
    roi = total_wagered > 0 ? (total_profit / total_wagered * 100).round(2) : 0

    {
      summary: {
        period: {
          start_date: start_date,
          end_date: end_date
        },
        total_bets: total_count,
        win_bets: win_count,
        lose_bets: lose_count,
        win_rate: total_count > 0 ? (win_count.to_f / total_count * 100).round(2) : 0,
        total_profit: total_profit.round(6),
        total_wagered: total_wagered,
        total_return: total_return,
        roi_percentage: roi,
        break_even_win_rate: BREAK_EVEN_WIN_RATE,
        # 当前胜率是否达到盈亏平衡
        above_break_even: (total_count > 0 ? (win_count.to_f / total_count * 100).round(2) : 0) >= BREAK_EVEN_WIN_RATE
      },
      amounts: {
        win_total: win_sum,
        lose_total: lose_sum,
        average_bet: total_count > 0 ? (total_wagered / total_count).round(6) : 0,
        average_win: win_count > 0 ? (win_sum / win_count).round(6) : 0,
        average_lose: lose_count > 0 ? (lose_sum / lose_count).round(6) : 0
      },
      # 盈利分析
      profit_analysis: {
        # 每次成功下注的预期盈利 = 下注金额 × (赔率 - 1) = 下注金额 × 0.95
        expected_profit_per_win_bet: BET_PROFIT_MULTIPLIER,
        # 每次失败下注的损失 = 下注金额
        loss_per_lose_bet: 1.0,
        # 达到盈亏平衡所需的最低胜率
        minimum_win_rate_for_profit: BREAK_EVEN_WIN_RATE,
        # 实际胜率距离盈亏平衡点的差距
        win_rate_gap: total_count > 0 ?
          ((win_count.to_f / total_count * 100) - BREAK_EVEN_WIN_RATE).round(2) : -BREAK_EVEN_WIN_RATE
      }
    }
  end
end
