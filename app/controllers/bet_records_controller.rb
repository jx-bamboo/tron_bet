class BetRecordsController < ApplicationController
  before_action :set_bet_record, only: %i[ show edit update destroy ]

  # GET /bet_records or /bet_records.json
  def index
    @bet_records = BetRecord.all
  end

  # GET /bet_records/1 or /bet_records/1.json
  def show
  end

  # GET /bet_records/new
  def new
    @bet_record = BetRecord.new
  end

  # GET /bet_records/1/edit
  def edit
  end

  # POST /bet_records or /bet_records.json
  def create
    @bet_record = BetRecord.new(bet_record_params)

    respond_to do |format|
      if @bet_record.save
        format.html { redirect_to @bet_record, notice: "Bet record was successfully created." }
        format.json { render :show, status: :created, location: @bet_record }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @bet_record.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /bet_records/1 or /bet_records/1.json
  def update
    respond_to do |format|
      if @bet_record.update(bet_record_params)
        format.html { redirect_to @bet_record, notice: "Bet record was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @bet_record }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @bet_record.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /bet_records/1 or /bet_records/1.json
  def destroy
    @bet_record.destroy!

    respond_to do |format|
      format.html { redirect_to bet_records_path, notice: "Bet record was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_bet_record
      @bet_record = BetRecord.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def bet_record_params
      params.expect(bet_record: [ :bot_id, :block_record_id, :bet_parity, :bet_amount, :result_parity, :success, :transaction_id, :failed_count ])
    end
end
