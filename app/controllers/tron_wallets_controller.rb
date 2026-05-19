class TronWalletsController < ApplicationController
  before_action :authenticate_admin!
  before_action :require_admin
  before_action :set_tron_wallet, only: %i[ show edit update destroy ]

  # GET /tron_wallets or /tron_wallets.json
  def index
    @tron_wallets = TronWallet.order(id: :desc)
  end

  # GET /tron_wallets/1 or /tron_wallets/1.json
  def show
  end

  # GET /tron_wallets/new
  def new
    @tron_wallet = TronWallet.new
  end

  # GET /tron_wallets/1/edit
  def edit
  end

  # POST /tron_wallets or /tron_wallets.json
  # def create
  #   @tron_wallet = TronWallet.new(tron_wallet_params)

  #   respond_to do |format|
  #     if @tron_wallet.save
  #       format.html { redirect_to @tron_wallet, notice: "Tron wallet was successfully created." }
  #       format.json { render :show, status: :created, location: @tron_wallet }
  #     else
  #       format.html { render :new, status: :unprocessable_entity }
  #       format.json { render json: @tron_wallet.errors, status: :unprocessable_entity }
  #     end
  #   end
  # end
  def create
    number = params.dig(:tron_wallet, :number)&.to_i
    number = [ number, 1 ].max
    number = [ number, 100 ].min

    TronWallet.transaction do
      wallets = number.times.map do
        key = Tron::Key.new
        TronWallet.new(
          address: key.address,
          private_key: key.private_hex
        )
      end

      wallets.each(&:save!) # 全部保存，失败则回滚
    end

    # 成功后跳转到列表页（符合多资源创建的惯例）
    redirect_to tron_wallets_path, notice: "#{number} 个钱包已成功生成！"
  rescue ActiveRecord::RecordInvalid, StandardError => e
    flash[:alert] = "生成失败：#{e.message}"
    render :new, status: :unprocessable_entity
  end

  # PATCH/PUT /tron_wallets/1 or /tron_wallets/1.json
  def update
    respond_to do |format|
      if @tron_wallet.update(tron_wallet_params)
        format.html { redirect_to @tron_wallet, notice: "Tron wallet was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @tron_wallet }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @tron_wallet.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tron_wallets/1 or /tron_wallets/1.json
  def destroy
    @tron_wallet.destroy!

    respond_to do |format|
      format.html { redirect_to tron_wallets_path, notice: "Tron wallet was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_tron_wallet
      @tron_wallet = TronWallet.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def tron_wallet_params
      params.expect(tron_wallet: [ :address, :private_key, :balance, :status, :member_id ])
    end
end
