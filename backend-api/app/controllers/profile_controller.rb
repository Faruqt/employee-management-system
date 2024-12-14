# ProfileController handles the profile-related actions for users.
#
# Includes:
# - AccessRequired: Ensures access control.
#
# Actions:
# - index: Fetches the profile of the current user based on the provided user type.
#
# Before Actions:
# - authenticate_user!: Ensures user is authenticated.
#
# Rescue From:
# - StandardError: Logs unexpected errors and returns a 500 internal server error.
#
# Private Methods:
# - user_class_for(user_type): Returns the user class (Employee or Admin) based on the user type.
# - validate_profile_params: Validates the presence and validity of the user type parameter.
# - render_error(message, status): Renders an error message with the specified status.
#
# Constants:
# - Constants::USER_TYPES: A list of valid user types ('employee', 'manager', 'director').
#
class ProfileController < ApplicationController
  # Include the required concerns
  include AccessRequired

  before_action :authenticate_user!

  before_action :validate_profile_params

  # GET /profile
  def index
    begin
      user = @current_user
      # get the user type of the user being changed
      user_type = params[:user_type]

      # get the user class based on the user type
      user_class = user_class_for(user_type)

      # get the user profile
      profile = user_class.find_by(email: user["email"])

      unless profile
        return render_error("User not found", :not_found)
      end

      render json: { profile: profile.public_attributes }
    rescue StandardError => e
      Rails.logger.error("An error occurred while fetching user profile: #{e.message}")
      render_error("An error occurred while fetching user profile, please try again")
    end
  end

  private
    # Get the user class based on the user type
    def user_class_for(user_type)
      case user_type
      when "employee" then Employee
      else Admin
      end
    end

    def validate_profile_params
      user_type = params[:user_type]

      if user_type.blank?
          return render_error("User type is required")
      end

      unless Constants::USER_TYPES.include?(user_type)
          render_error("The user type you provided is invalid. Please provide a valid user type: 'employee', 'manager', or 'director'.")
      end
    end

    def render_error(message, status = :bad_request)
        render json: { error: message }, status: status
    end
end
