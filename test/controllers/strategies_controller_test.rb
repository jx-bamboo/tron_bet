require "test_helper"

class StrategiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @strategy = strategies(:one)
  end

  test "should get index" do
    get strategies_url
    assert_response :success
  end

  test "should get new" do
    get new_strategy_url
    assert_response :success
  end

  test "should create strategy" do
    assert_difference("Strategy.count") do
      post strategies_url, params: { strategy: {} }
    end

    assert_redirected_to strategy_url(Strategy.last)
  end

  test "should show strategy" do
    get strategy_url(@strategy)
    assert_response :success
  end

  test "should get edit" do
    get edit_strategy_url(@strategy)
    assert_response :success
  end

  test "should update strategy" do
    patch strategy_url(@strategy), params: { strategy: {} }
    assert_redirected_to strategy_url(@strategy)
  end

  test "should destroy strategy" do
    assert_difference("Strategy.count", -1) do
      delete strategy_url(@strategy)
    end

    assert_redirected_to strategies_url
  end
end
