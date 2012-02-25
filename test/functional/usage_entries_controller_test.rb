require 'test_helper'

class UsageEntriesControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:usage_entries)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create usage_entry" do
    assert_difference('UsageEntry.count') do
      post :create, :usage_entry => { }
    end

    assert_redirected_to usage_entry_path(assigns(:usage_entry))
  end

  test "should show usage_entry" do
    get :show, :id => usage_entries(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => usage_entries(:one).to_param
    assert_response :success
  end

  test "should update usage_entry" do
    put :update, :id => usage_entries(:one).to_param, :usage_entry => { }
    assert_redirected_to usage_entry_path(assigns(:usage_entry))
  end

  test "should destroy usage_entry" do
    assert_difference('UsageEntry.count', -1) do
      delete :destroy, :id => usage_entries(:one).to_param
    end

    assert_redirected_to usage_entries_path
  end
end
