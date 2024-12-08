require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest

    test "user cannot access non existent route" do
        get '/non_existent_route'
        assert_response :not_found
        assert JSON.parse(@response.body)["error"]
        assert_equal "Route not found, please check the URL or try another route", JSON.parse(@response.body)["error"]
    end
end