ENV["RAILS_ENV"] ||= "test"
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

      # Stubbing the register_user method to return a successful response
      CognitoService.any_instance.stubs(:register_user).returns(true)

    end

    # Add more helper methods to be used by all tests here...
  end
end
