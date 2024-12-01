require "test_helper"

class WelcomeControllerTest < ActionDispatch::IntegrationTest
  test "user can reach base route succesfully" do
    assert ActiveRecord::Base.connection.active?, "Database connection failed"

    # Get the root URL
    get root_path

    # Assert that the response was successful
    assert_response :success

    # Assert that the response body contains the welcome text
    assert_equal "Welcome to the shift management system API! Your request was successful.", response.parsed_body["message"]
  end
end
