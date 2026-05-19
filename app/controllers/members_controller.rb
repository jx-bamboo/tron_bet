class MembersController < ApplicationController
  before_action :authenticate_admin!
  before_action :require_admin
  before_action :set_member, only: %i[ show edit update destroy ]

  # GET /members or /members.json
  def index
    @members = Member.all.order(created_at: :desc)
  end

  # GET /members/1 or /members/1.json
  def show
    @bot = @member.bot
    @bet_records = @bot&.bet_records&.order(created_at: :desc)&.limit(20) || []


    # 获取今日统计
    @today_stats = @member.today_betting_stats

    # 获取总统计
    @total_stats = @member.betting_statistics

    # 获取最近30天盈利趋势
    @daily_profit_trend = @member.daily_profit_trend(days: 30).reverse

    # 获取最近的下注记录
    @recent_bets = @member.bet_records
      .includes(:block_record)
      .order(created_at: :desc)
      .limit(20)
  end

  # GET /members/new
  def new
    @member = Member.new
  end

  # GET /members/1/edit
  def edit
  end

  # POST /members or /members.json
  def create
    @member = Member.new(member_params)

    respond_to do |format|
      if @member.save
        format.html { redirect_to @member, notice: "Member was successfully created." }
        format.json { render :show, status: :created, location: @member }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @member.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /members/1 or /members/1.json
  def update
    current_strategy = @member.strategy
    edit_strategy = params[:member][:strategy]  # "zl2"

    respond_to do |format|
      if @member.update(member_params)
        if current_strategy != edit_strategy
          @member.bot&.update(strategy_type: edit_strategy)
        end
        format.html { redirect_to @member, notice: "Member was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @member }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @member.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /members/1 or /members/1.json
  def destroy
    @member.destroy!

    respond_to do |format|
      format.html { redirect_to members_path, notice: "Member was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # POST /members/1/start_bot
  def start_bot
    @member = Member.find(params[:id])
    success, message = @member.start_bot!
    puts message, "..."

    if success
      redirect_to @member, notice: message
    else
      redirect_to @member, notice: message
    end
  end

  # POST /members/1/stop_bot
  def stop_bot
    @member = Member.find(params[:id])
    success, message = @member.stop_bot!

    if success
      redirect_to @member, notice: message
    else
      redirect_to @member, alert: message
    end
  end

  # 盈利报表API
  def profit_report
    @member = Member.find(params[:id])

    start_date = params[:start_date]&.to_date || 30.days.ago.to_date
    end_date = params[:end_date]&.to_date || Date.today

    # 生成详细报表
    @report = @member.profit_report(start_date, end_date)

    respond_to do |format|
      format.json { render json: @report }
      format.html
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_member
      @member = Member.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def member_params
      params.fetch(:member, {}).permit(:username, :tron_address, :tron_private_key, :strategy)
    end

    def today_profit
      start_time = Date.today.beginning_of_day
      end_time   = Date.today.end_of_day

      result = bet_records
        .where(success: [ true, false ]) # 排除 nil
        .where(created_at: start_time..end_time)
        .group(:success)
        .sum(:bet_amount)

      win_sum  = (result[true] || 0).to_f
      lose_sum = (result[false] || 0).to_f

      (win_sum * 1.95) - lose_sum
    end
end
