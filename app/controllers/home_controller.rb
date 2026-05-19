class HomeController < ApplicationController
  before_action :authenticate_admin!, only: [ :map ]
  before_action :require_admin, only: [ :map ]
  def index
    @total_members = Member.count
    @active_members = Member.where(active: true).count
    @total_bots = Bot.count

    # 修复查询语法，使用字符串形式的状态
    @active_bots = Bot.where(status: [ "running", "waiting_result" ]).count

    @total_blocks = BlockRecord.count
    @today_blocks = BlockRecord.where("created_at >= ?", Time.current.beginning_of_day).count
    @total_bets = BetRecord.count
    @today_bets = BetRecord.where("created_at >= ?", Time.current.beginning_of_day).count

    # 最近的下注记录
    @recent_bets = BetRecord.includes(:bot, :block_record, bot: :member)
                           .order(created_at: :desc)
                           .limit(10)

    # 最近的区块记录
    @recent_blocks = BlockRecord.order(block_time: :desc).limit(10)

    # 系统状态
    @system_status = check_system_status
  end

  def map
    data = BlockRecord.recent_with_groups(limit: 200)
    @records = data[:records]
    @groups  = data[:groups]
  end

  private

  def check_system_status
    # 检查区块监控是否正常运行
    last_block = BlockRecord.order(block_time: :desc).first
    if last_block && last_block.block_time >= 2.minutes.ago
      { status: "normal", message: "系统运行正常", icon: "check-circle" }
    else
      { status: "warning", message: "区块监控可能异常", icon: "exclamation-triangle" }
    end
  end
end
