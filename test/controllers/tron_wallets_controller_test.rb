require "test_helper"

class TronWalletsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tron_wallet = tron_wallets(:one)
  end

  test "should get index" do
    get tron_wallets_url
    assert_response :success
  end

  test "should get new" do
    get new_tron_wallet_url
    assert_response :success
  end

  test "should create tron_wallet" do
    assert_difference("TronWallet.count") do
      post tron_wallets_url, params: { tron_wallet: {} }
    end

    assert_redirected_to tron_wallet_url(TronWallet.last)
  end

  test "should show tron_wallet" do
    get tron_wallet_url(@tron_wallet)
    assert_response :success
  end

  test "should get edit" do
    get edit_tron_wallet_url(@tron_wallet)
    assert_response :success
  end

  test "should update tron_wallet" do
    patch tron_wallet_url(@tron_wallet), params: { tron_wallet: {} }
    assert_redirected_to tron_wallet_url(@tron_wallet)
  end

  test "should destroy tron_wallet" do
    assert_difference("TronWallet.count", -1) do
      delete tron_wallet_url(@tron_wallet)
    end

    assert_redirected_to tron_wallets_url
  end
end
