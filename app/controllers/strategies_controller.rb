class StrategiesController < ApplicationController
  before_action :set_strategy, only: %i[ show edit update destroy ]

  # GET /strategies or /strategies.json
  def index
    @strategies = Strategy.all
  end

  # GET /strategies/1 or /strategies/1.json
  def show
  end

  # GET /strategies/new
  def new
    @strategy = Strategy.new
  end

  # GET /strategies/1/edit
  def edit
  end

  # POST /strategies or /strategies.json
  def create
    @strategy = Strategy.new(strategy_params)

    respond_to do |format|
      if @strategy.save
        format.html { redirect_to @strategy, notice: "Strategy was successfully created." }
        format.json { render :show, status: :created, location: @strategy }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @strategy.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /strategies/1 or /strategies/1.json
  def update
    respond_to do |format|
      if @strategy.update(strategy_params)
        format.html { redirect_to @strategy, notice: "Strategy was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @strategy }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @strategy.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /strategies/1 or /strategies/1.json
  def destroy
    @strategy.destroy!

    respond_to do |format|
      format.html { redirect_to strategies_path, notice: "Strategy was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_strategy
      @strategy = Strategy.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def strategy_params
      params.fetch(:strategy, {})
    end
end
