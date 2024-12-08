ENV["RAILS_ENV"] ||= "test"
ENV["AWS_REGION"] = "some-region"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def setup_cognito_mock
      # Create a mock of CognitoService
      @mock_cognito_service = mock("CognitoService")

      # Stub the register_user method to return a successful response
      @mock_cognito_service.stubs(:register_user).returns(true)

      # Mock the CognitoService initialization to return the mock object
      CognitoService.stubs(:new).returns(@mock_cognito_service)

    end

    # Add more helper methods to be used by all tests here...
  end
end
