class BotsController < ApplicationController
  before_action :authenticate_admin!, :require_admin
  before_action :set_bot, only: %i[ show edit update destroy ]

  # GET /bots or /bots.json
  def index
    @bots = Bot.all
  end

  # GET /bots/1 or /bots/1.json
  def show
  end

  # GET /bots/new
  def new
    @bot = Bot.new
  end

  # GET /bots/1/edit
  def edit
  end

  # POST /bots or /bots.json
  def create
    @bot = Bot.new(bot_params)

    respond_to do |format|
      if @bot.save
        format.html { redirect_to @bot, notice: "Bot was successfully created." }
        format.json { render :show, status: :created, location: @bot }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @bot.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /bots/1 or /bots/1.json
  def update
    respond_to do |format|
      if @bot.update(bot_params)
        format.html { redirect_to @bot, notice: "Bot was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @bot }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @bot.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /bots/1 or /bots/1.json
  def destroy
    @bot.destroy!

    respond_to do |format|
      format.html { redirect_to bots_path, notice: "Bot was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_bot
      @bot = Bot.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def bot_params
      params.expect(bot: [ :member_id, :status, :monitor_count, :consecutive_count, :current_parity, :failed_times, :bet_amount_index, :last_checked_block, :start_balance, :end_balance, :profit, :started_at, :stopped_at ])
    end
end
