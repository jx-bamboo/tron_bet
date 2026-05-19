require "test_helper"

class BetRecordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @bet_record = bet_records(:one)
  end

  test "should get index" do
    get bet_records_url
    assert_response :success
  end

  test "should get new" do
    get new_bet_record_url
    assert_response :success
  end

  test "should create bet_record" do
    assert_difference("BetRecord.count") do
      post bet_records_url, params: { bet_record: {} }
    end

    assert_redirected_to bet_record_url(BetRecord.last)
  end

  test "should show bet_record" do
    get bet_record_url(@bet_record)
    assert_response :success
  end

  test "should get edit" do
    get edit_bet_record_url(@bet_record)
    assert_response :success
  end

  test "should update bet_record" do
    patch bet_record_url(@bet_record), params: { bet_record: {} }
    assert_redirected_to bet_record_url(@bet_record)
  end

  test "should destroy bet_record" do
    assert_difference("BetRecord.count", -1) do
      delete bet_record_url(@bet_record)
    end

    assert_redirected_to bet_records_url
  end
end
