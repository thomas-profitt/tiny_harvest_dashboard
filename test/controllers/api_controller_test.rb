require 'test_helper'

class ApiControllerTest < ActionController::TestCase
  test "should get random_porn" do
    get :random_porn
    assert_response :success
  end

end
