class PasswordsController < ApplicationController
    # Include the required concerns
    include AccessRequired
    include RolesRequired

    before_action :authenticate_user!, only: [ :admin_reset_password, :change_password ]

    # ensure only directors, managers, and super admins can reset passwords of other users
    before_action -> { roles_required([ "director", "manager", "super_admin" ]) }, only: [ :admin_reset_password ]

    before_action :validate_set_new_password_params, only: [ :set_new_password ]
    before_action :validate_reset_password_params, only: [ :reset_password ]
    before_action :validate_admin_reset_password_params, only: [ :admin_reset_password ]
    before_action :validate_request_password_reset_params, only: [ :request_password_reset ]
    before_action :validate_change_password_params, only: [ :change_password ]
    before_action :check_user_exists, only: [ :set_new_password, :request_password_reset, :reset_password, :admin_reset_password ]
    before_action :check_who_can_reset_password, only: [ :admin_reset_password ]

    # Set up the Cognito service
    before_action :set_cognito_service

    # POST auth/password/set
    def set_new_password
        email = params[:email]
        new_password = params[:new_password]
        session_code = params[:session_code]

        begin
            # set the new password
            @cognito_service.set_new_password(email, new_password, session_code)
            # verify the email
            @cognito_service.verify_email(email)

            render json: { message: "Password set successfully" }, status: :ok
        rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
            Rails.logger.error("Error setting new password: #{e.message}")
            handle_cognito_error(e)
            nil
        rescue StandardError => e
            Rails.logger.error("Unexpected error: #{e.message}")
            render json: { error: "An error occurred while setting new password, please try again" }, status: :internal_server_error
        end
    end

    # POST auth/password/forgot
    def request_password_reset
        email = params[:email]

        begin
            @cognito_service.request_password_reset(email)
            render json: { message: "Password reset code sent successfully to #{email}" }, status: :ok
        rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
            Rails.logger.error("Error requesting password reset: #{e.message}")
            handle_cognito_error(e)
            nil
        rescue StandardError => e
            Rails.logger.error("Unexpected error: #{e.message}")
            render json: { error: "An error occurred while requesting password reset, please try again" }, status: :internal_server_error
        end
    end

    #  POST auth/password/reset
    def reset_password
        email = params[:email]
        new_password = params[:new_password]
        confirmation_code = params[:confirmation_code]

        begin
            # reset the password
            @cognito_service.reset_password(email, new_password, confirmation_code)

            render json: { message: "Password reset successfully" }, status: :ok
        rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
            Rails.logger.error("Error resetting password: #{e.message}")
            handle_cognito_error(e)
            nil
        rescue StandardError => e
            Rails.logger.error("Unexpected error: #{e.message}")
            render json: { error: "An error occurred while resetting password, please try again" }, status: :internal_server_error
        end
    end

    # POST /auth/admin/password/reset
    def admin_reset_password
        email = params[:email]
        new_password = params[:new_password]

        begin
            # set the new password
            @cognito_service.admin_set_password(email, new_password)

            # verify the email incase it was not verified
            @cognito_service.verify_email(email)

            render json: { message: "Password reset for #{email} was successful" }, status: :ok
        rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
            Rails.logger.error("Error resetting password: #{e.message}")
            handle_cognito_error(e)
            nil
        rescue StandardError => e
            Rails.logger.error("Unexpected error: #{e.message}")
            render json: { error: "An error occurred while resetting password, please try again" }, status: :internal_server_error
        end
    end

    # POST /auth/password/change
    def change_password
        token = @current_user["access_token"]
        old_password = params[:old_password]
        new_password = params[:new_password]

        begin
            # change the password
            @cognito_service.change_password(token, old_password, new_password)

            render json: { message: "Password changed successfully" }, status: :ok
        rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
            Rails.logger.error("Error changing password: #{e.message}")
            handle_cognito_error(e)
            nil
        rescue StandardError => e
            Rails.logger.error("Unexpected error: #{e.message}")
            render json: { error: "An error occurred while changing password, please try again" }, status: :internal_server_error
        end
    end


    private

    # Set up the Cognito service for the controller actions
    def set_cognito_service
        @cognito_service = CognitoService.new
    end

    def validate_set_new_password_params
        email = params[:email]
        new_password = params[:new_password]
        session_code = params[:session_code]

        # Check if email, new_password, and session_code are present
        if email.blank? || new_password.blank? || session_code.blank?
            return render_error("Email, new password, and session code are required")
        end

        check_email_is_valid(email)
    end

    def validate_request_password_reset_params
        email = params[:email]

        # Check if email is present
        if email.blank?
            return render_error("Email is required")
        end

        check_email_is_valid(email)
    end

    def validate_reset_password_params
        email = params[:email]
        new_password = params[:new_password]
        confirmation_code = params[:confirmation_code]

        # Check if email, new_password, and confirmation_code are present
        if email.blank? || new_password.blank? || confirmation_code.blank?
            return render_error("Email, new password, and confirmation code are required")

        end

        check_email_is_valid(email)
    end

    def validate_admin_reset_password_params
        email = params[:email]
        new_password = params[:new_password]
        user_type = params[:user_type]

        if user_type.blank?
            return render_error("User type is required")
        end

        unless Constants::USER_TYPES.include?(user_type)
            return render_error("The user type you provided is invalid. Please provide a valid user type: 'employee', 'manager', or 'director'.")
        end

        # Check if email and new_password are present
        if email.blank? || new_password.blank?
            return render_error("Email and new password are required")
        end

        check_email_is_valid(email)
    end

    def validate_change_password_params
        old_password = params[:old_password]
        new_password = params[:new_password]

        # Check if old_password, and new_password are present
        if old_password.blank? || new_password.blank?
            render_error("Old password and new password are required")
        end
    end

    def check_email_is_valid(email)
        unless email =~ URI::MailTo::EMAIL_REGEXP
            render_error("The email provided is invalid. Please provide a valid email address.", :bad_request)
        end
    end

    def check_user_exists
        email = params[:email]

        user = Employee.find_by(email: email)
        if !user
            user = Admin.find_by(email: email)
        end

        unless user
            render_error("User not found", :not_found)
        end
    end

    def check_who_can_reset_password
        # to change password , the user changing the password must be of a higher role than the user being changed
        # for example, a manager can change the password of an employee but cannot change the password of another manager or a director
        # a director can change the password of a manager but cannot change the password of another director or a super admin
        # a super admin can change the password of a director but cannot change the password of another super admin

        # get the user type of the user being changed
        user_type = params[:user_type]

        # get the user type of the user changing the password
        current_user = @current_user
        current_user_email = current_user["email"]

        # retrieve the admin changing the password
        admin = Admin.find_by(email: current_user_email)

        # check if the admin exists
        unless admin
            return render_error("Admin not found", :not_found)
        end

        # check if the admin has the required role to change the password
        if user_type == "employee"
            # check if the admin is a manager or a director
            unless admin.is_manager || admin.is_director || admin.is_super_admin
                Rails.logger.error("#{current_user_email} tried to reset the password of an employee")
                render_error("You are not authorized to reset the password of an employee", :unauthorized)
            end

        elsif user_type == "manager"
            # check if the admin is a director or a super admin
            unless admin.is_director || admin.is_super_admin
                Rails.logger.error("#{current_user_email} tried to reset the password of a manager")
                render_error("You are not authorized to reset the password of a manager", :unauthorized)
            end

        elsif user_type == "director"
            # check if the admin is a super admin
            unless admin.is_super_admin
                Rails.logger.error("#{current_user_email} tried to reset the password of a director")
                render_error("You are not authorized to reset the password of a director", :unauthorized)
            end
        else
            render_error("The user type you provided is invalid. Please provide a valid user type: 'employee', 'manager', or 'director'.", :bad_request)
        end
    end

    def render_error(message, status = :bad_request)
        render json: { error: message }, status: status
    end

    def handle_cognito_error(error)
        # Check if the error response exists before trying to access it
        case error
        when Aws::CognitoIdentityProvider::Errors::InvalidPasswordException
            render json: { error: "Password does not meet the requirements" }, status: :bad_request
        when Aws::CognitoIdentityProvider::Errors::CodeMismatchException
            render json: { error: "Invalid session code" }, status: :bad_request
        when Aws::CognitoIdentityProvider::Errors::ExpiredCodeException
            render json: { error: "Session code has expired" }, status: :bad_request
        when Aws::CognitoIdentityProvider::Errors::UserNotConfirmedException
            render json: { error: "Account not confirmed" }, status: :bad_request
        when Aws::CognitoIdentityProvider::Errors::UserNotFoundException
            render json: { error: "Account does not exist" }, status: :bad_request
        when Aws::CognitoIdentityProvider::Errors::NotAuthorizedException
            render json: { error: "Invalid email or password" }, status: :bad_request
        else
            render json: { error: "An error occurred while trying to reset your password, please try again" }, status: :internal_server_error
        end
    end
end
