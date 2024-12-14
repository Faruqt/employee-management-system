# UserManagementController handles user management actions such as listing, showing, archiving, and deleting users.
#
# Actions:
# - `index`: Lists users based on the `user_type` parameter with pagination.
# - `archived`: Lists archived users with pagination.
# - `show`: Shows details of a specific user.
# - `toggle_archive_state`: Toggles the archive state of a user based on the `action_type` parameter.
# - `destroy`: Deletes a user and anonymizes their sensitive details.
#
# Before Actions:
# - `authenticate_user!`: Ensures the user is authenticated.
# - `set_cognito_service`: Sets up the Cognito service for user management.
# - `roles_required`: Ensures that only users with roles "director", "manager", or "super_admin" can access these routes.
# - `check_params`: Ensures that `user_type` is present before trying to log in (only for `index` action).
#
# Rescue From:
# - `StandardError`: Logs unexpected errors and returns a 500 internal server error.
# - `Aws::CognitoIdentityProvider::Errors::ServiceError`: Handles errors from the Cognito service.
# - `ActiveRecord::RecordInvalid`: Handles validation errors during delete action.
#
# Private Methods:
# - `set_cognito_service`: Sets up the Cognito service for the controller actions.
# - `render_error`: Renders an error message with a specified status.
# - `check_params`: Ensures that `user_type` is present and valid.
# - `check_user_exists`: Checks if a user exists based on the `id` parameter.
# - `check_user_that_can_get_users_list`: Checks if the current user is authorized to get the list of users.
# - `check_user_can_delete_another_user`: Checks if the current user is authorized to delete another user.
# - `render_users`: Renders a list of users with pagination metadata.
# - `pagination_setup`: Sets up pagination parameters.
#
# Constants:
# - `Constants::USER_TYPES`: A list of valid user types ('employee', 'manager', 'director').
# - `Constants::DEFAULT_PER_PAGE`: Default number of items per page for pagination.

class UserManagementController < ApplicationController
  # Include the required concerns
  include AccessRequired
  include RolesRequired

  before_action :authenticate_user!

  # Set up the Cognito service
  before_action :set_cognito_service

  # Ensure that super admins, managers, and directors can access these routes
  before_action -> { roles_required([ "director", "manager", "super_admin" ]) }

  # Check if user_type is present before trying to log in
  before_action :check_params, only: [ :index ]

  # GET /users/:user_type
  def index
    begin
      user_type = params[:user_type]

      page, per_page = pagination_setup(params)

      # Use kaminari's `page` and `per` methods to paginate
      if user_type == "employee"
        users = Employee.where(is_deleted: false, is_active: true).page(page).per(per_page).order(created_at: :desc)
      else
        users = Admin.where(is_deleted: false).page(page).per(per_page).order(created_at: :desc)
      end

      render_users(users)
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while fetching users, please try again" }, status: :internal_server_error
    end
  end

  # GET /users/status/archived
  def archived
    begin

      page, per_page = pagination_setup(params)

      # Use kaminari's `page` and `per` methods to paginate
      users = Employee.where(is_deleted: false, is_active: false).page(page).per(per_page).order(created_at: :desc)

      render_users(users)
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while fetching archived users, please try again" }, status: :internal_server_error
    end
  end

  # GET /users/:id
  def show
    begin
      user = check_user_exists

      return unless user

      Rails.logger.info("Fetched user successfully")
      render json: { user: user.public_attributes }
    rescue StandardError => e
      Rails.logger.error("An error occurred while fetching user: #{e.message}")
      render_error("An error occurred while fetching user, please try again")
    end
  end

  # POST /toggle_archive_state
  def toggle_archive_state
    begin
      # Toggle archive status based on the `action_type` parameter
      user = check_user_exists
      return unless user

      unless params[:action_type]
        return render_error("Action type is required", :bad_request)
      end

      action = params[:action_type].to_s.downcase
      case action
      when "true", "archive"
        user.is_active = false
        message = "User archived successfully"
      when "false", "unarchive"
        user.is_active = true
        message = "User unarchived successfully"
      else
        return render_error("Invalid action. Use 'true' or 'false' for the 'action_type' parameter.", :bad_request)
      end

      user.save!
      render json: { message: message, user: user.public_attributes }
    rescue StandardError => e
      Rails.logger.error("An error occurred while updating user archive status: #{e.message}")
      render_error("An error occurred while updating user archive status, please try again")
    end
  end

  # DELETE /users/:id
  def destroy
    ActiveRecord::Base.transaction do
      begin
        user = check_user_exists("delete")
        return unless user

        # Check if the user can be deleted
        return unless check_user_can_delete_another_user(user)

        user_email = user.email

        # Anonymise the sensitive details of the user
        user.update!(is_deleted: true, email: "deleted_user#{user.id}@deleted.com", telephone: "000000", first_name: "Deleted", last_name: "User")

        # Attempt to delete the user in Cognito
        @cognito_service.delete_user(user_email)

        render json: { message: "User deleted successfully" }
      rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
        Rails.logger.error("Deleting user failed: #{e.message}")
        raise ActiveRecord::Rollback, "Failed to delete user in Cognito"
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("Deleting user failed: #{e.message}")
        raise ActiveRecord::Rollback, "Failed to update user in database"
      rescue StandardError => e
        Rails.logger.error("An error occurred while deleting user: #{e.message}")
        raise ActiveRecord::Rollback, "Unexpected error occurred"
      end
    end
  rescue ActiveRecord::Rollback => e
    render_error(e.message || "An error occurred while deleting user, please try again")
  end



  private
  # Set up the Cognito service for the controller actions
  def set_cognito_service
    @cognito_service = CognitoService.new
  end

  def render_error(message, status = :bad_request)
    render json: { error: message }, status: status
  end

  def check_params
    # Ensure that user_type is present
    unless params[:user_type].present?
      return render_error("User type is required. Please specify if you're registering an 'employee', 'manager', or 'director'.")
    end

    user_type = params[:user_type]

    # Ensure that user_type is valid
    unless Constants::USER_TYPES.include?(user_type)
      return render_error("The user type you provided is invalid. Please provide a valid user type: 'employee', 'manager', or 'director'.")
    end

    check_user_that_can_get_users_list(user_type)
  end

  def check_user_exists(action = "show")
    user_id = params[:id]

    if user_id.blank?
      render_error("User ID is required", :bad_request)
      return nil
    end

    # Find the user in the Employee model
    user = Employee.find_by(id: user_id)
    if action == "delete" && !user
      # check if the user is an admin
      user = Admin.find_by(id: user_id)
    end

    unless user
      render_error("User not found", :not_found)
      return nil
    end

    user
  end

  def check_user_that_can_get_users_list(user_type)
    # get the user type of the user getting the list of users
    current_user = @current_user
    current_user_email = current_user["email"]

    # retrieve the admin
    admin = Admin.find_by(email: current_user_email)

    # check if the admin exists
    unless admin
      return render_error("Admin not found", :not_found)
    end

    # Check if a manager is trying to get a list of managers or directors
    # then check class of user
    if admin.admin_type == Admin.admin_types[:manager] && (user_type == Admin.admin_types[:manager] || user_type == Admin.admin_types[:director])
      render_error("You are not authorized to carry out this action", :unauthorized)
    elsif admin.admin_type == Admin.admin_types[:director] && user_type == Admin.admin_types[:director]
      render_error("You are not authorized to carry out this action", :unauthorized)
    end
  end

  def check_user_can_delete_another_user(user)
    # get the user type of the user deleting another user
    current_user = @current_user
    current_user_email = current_user["email"]

    # retrieve the admin
    admin = Admin.find_by(email: current_user_email)

    # check if the admin exists
    unless admin
      render_error("Admin not found", :not_found)
      return false
    end

    # Check if a manager is trying to update a manager or director
    # then check class of user
    if admin.admin_type == Admin.admin_types[:manager] && user.is_a?(Admin) && (user.admin_type == Admin.admin_types[:manager] || user.admin_type == Admin.admin_types[:director])
      render_error("You are not authorized to carry out this action", :unauthorized)
      return false
    elsif admin.admin_type == Admin.admin_types[:director] && user.is_a?(Admin) && (user.admin_type == Admin.admin_types[:director] || user.admin_type == Admin.admin_types[:super_admin])
      render_error("You are not authorized to carry out this action", :unauthorized)
      return false
    end

    true
  end

  def render_users(users)
    next_page_url = users.next_page ? url_for(page: users.next_page, per_page: per_page) : nil
    prev_page_url = users.prev_page ? url_for(page: users.prev_page, per_page: per_page) : nil
    Rails.logger.info("Fetched users successfully")
    render json: {
      users: users.map(&:public_attributes),
      meta: {
        current_page: users.current_page,
        total_pages: users.total_pages,
        total_count: users.total_count,
        next_page: next_page_url,
        prev_page: prev_page_url
      }
    }, status: :ok
  end

  def pagination_setup(params)
    # Default page is 1, and per_page is defined in constants.rb
    page = (params[:page] || 1).to_i
    # Ensure page is at least 1
    page = 1 if page < 1

    per_page = (params[:per_page] || Constants::DEFAULT_PER_PAGE).to_i
    per_page = Constants::DEFAULT_PER_PAGE if per_page < 1 # ensure per_page is a positive integer

    [ page, per_page ]
  end
end
