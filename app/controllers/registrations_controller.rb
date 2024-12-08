class RegistrationsController < ApplicationController
  # Check if email and user_type are present before trying to log in
  before_action :check_params, only: [ :create ]

  # Set up the Cognito service
  before_action :set_cognito_service

  # POST /register
  def create
    attributes = user_params.to_h.symbolize_keys
    begin
      # Ensure email uniqueness
      user_class = user_class_for(attributes[:user_type])
      if user_class.find_by(email: attributes[:email])
        render json: { error: "Account already exists with the email" }, status: :bad_request
        return
      end

      # Create the user
      user = create_user(attributes)

      Rails.logger.info("User #{user.id} created successfully")
      render json: {user: user.public_attributes, message: "User created successfully" }, status: :created

    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("An error occurred while creating user: #{e.message}")
      render json: { error: "An error occurred while creating user, please try again" }, status: :bad_request
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      Rails.logger.error("Error creating user: #{e.message}")
      handle_cognito_error(e)
      return
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while creating user, please try again" }, status: :internal_server_error
    end
  end

  private
  # Set up the Cognito service for the controller actions
  def set_cognito_service
    @cognito_service = CognitoService.new
  end

  # Set up the user params
  def user_params
    params.permit(:first_name, :last_name, :email, :telephone, :user_type, :branch_id, :area_id,
                  :contract_code, :tax_code, :date_of_birth, :contract_start_date, :contract_end_date)
  end

  # Get the user class based on the user type
  def user_class_for(user_type)
    case user_type
    when "employee" then User
    else Admin
    end
  end

  # Create a user based on the user type
  def create_user(attributes)
    user_type = attributes[:user_type]
    # Create the user in the local database without the password
    user = case user_type
          when 'employee'
            create_employee(attributes)
          when 'director', 'manager'
            create_admin(attributes, user_type)
          else
            raise 'Unknown user type'
          end

    # After user is created, call the external service (e.g., Cognito) to store the password
    password = Utils::PasswordGenerator.generate_password(6)

    begin
      cognito_response = @cognito_service.register_user(attributes[:email], password)
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      # Handle error registering user in Cognito
      user.destroy
      raise e
    end
    
    user
  end

  def create_employee(attributes)
    Employee.create!(
      first_name: attributes[:first_name],
      last_name: attributes[:last_name],
      email: attributes[:email],
      telephone: attributes[:telephone],
      branch_id: attributes[:branch_id],
      area_id: attributes[:area_id],
      contract_code: attributes[:contract_code],
      tax_code: attributes[:tax_code],
      date_of_birth: attributes[:date_of_birth],
      contract_start_date: attributes[:contract_start_date],
      contract_end_date: attributes[:contract_end_date]
    )
  end

  def create_admin(attributes, user_type)
    admin = Admin.create!(
      first_name: attributes[:first_name],
      last_name: attributes[:last_name],
      email: attributes[:email],
      telephone: attributes[:telephone],
      branch_id: attributes[:branch_id]
    )
    
    set_admin_role(attributes, admin, user_type)
    admin.save!
    
    admin
  end

  def set_admin_role(attributes, admin, user_type)
    case user_type
    when 'manager'
      admin.is_manager = true
      admin.area_id = attributes[:area_id]
    when 'director'
      admin.is_director = true
    end
  end

  def check_params
    # Ensure that user_type is present
    unless params[:user_type].present?
      render json: { error: "User type is required. Please specify if you're registering an 'employee', 'manager', or 'director'." }, status: :bad_request
      return
    end

    # Ensure that user_type is valid
    unless Constants::USER_TYPES.include?(params[:user_type])
      render json: { error: "The user type you provided is invalid. Please provide a valid user type: 'employee', 'manager', or 'director'." }, status: :bad_request
      return
    end

    # Define the required parameters based on user type
    required_params = %i[first_name email telephone user_type]
    required_params += [:branch_id, :area_id] if %w[employee manager].include?(params[:user_type])
    required_params += [:branch_id] if params[:user_type] == "director"
    
    # Check for any missing parameters
    missing = required_params.reject { |key| params[key].present? }
    
    if missing.any?
      missing_params = missing.join(', ')
      error_message = "The following required fields are missing: #{missing_params}. Please provide them to proceed."
      render json: { error: error_message }, status: :bad_request
      return
    end

    # Check if email is valid
    unless Utils::EmailValidator.valid?(params[:email])
      render json: { error: "The email provided is invalid. Please provide a valid email address." }, status: :bad_request
      return
    end
  end

  def handle_cognito_error(error)
    # Check if the error response exists before trying to access it
    case error
    when Aws::CognitoIdentityProvider::Errors::InvalidPasswordException
      render json: { error: "Password does not meet the requirements" }, status: :bad_request
    when Aws::CognitoIdentityProvider::Errors::UserAlreadyExistsException
      render json: { error: "User already exists" }, status: :bad_request
    when Aws::CognitoIdentityProvider::Errors::InvalidParameterException
      render json: { error: "Invalid parameters" }, status: :bad_request
    when Aws::CognitoIdentityProvider::Errors::TooManyRequestsException
      render json: { error: "Too many requests" }, status: :bad_request
    else
      render json: { error: "An error occurred while creating user, please try again" }, status: :internal_server_error
    end
  end
end
