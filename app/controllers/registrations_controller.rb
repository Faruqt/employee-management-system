#
# RegistrationsController handles the user registration process, including creating employees and admins,
# registering them with AWS Cognito, generating QR codes, and uploading files to S3.
#
# Actions:
# - create: Registers a new user (either 'employee', 'manager', or 'director') and performs the necessary actions,
#   including creating a local database record, generating a unique shift code, generating a QR code, and uploading it to S3.
#
# Before Actions:
# - before_action :authenticate_user!: Ensures the user is authenticated.
# - before_action -> { roles_required([ "director", "manager", "super_admin" ]) }: Ensures only directors, managers, and super admins can create users.
# - before_action :check_params, only: [:create]: Ensures the required parameters are provided for user registration.
# - before_action :set_cognito_service: Initializes the CognitoService for user registration with AWS Cognito.
# - before_action :set_file_upload_service: Initializes the FileUploadService for uploading files to S3.
#
# Rescue From:
# - ActiveRecord::RecordInvalid: Handles validation errors when creating a user in the database and returns a bad request response.
# - Aws::CognitoIdentityProvider::Errors::ServiceError: Handles errors from the AWS Cognito service and returns an appropriate error message.
# - StandardError: Catches unexpected errors, logs them, and returns an internal server error response.
#
# Private Methods:
# - set_cognito_service: Initializes and returns an instance of CognitoService for interacting with AWS Cognito.
# - set_file_upload_service: Initializes and returns an instance of FileUploadService for handling file uploads to S3.
# - user_params: Permits and returns the parameters required for user registration (e.g., first name, last name, email, user type).
# - user_class_for: Returns the appropriate user class based on the user type (e.g., Employee or Admin).
# - create_user: Handles the user creation process, including interacting with AWS Cognito for user registration.
# - create_employee: Creates a new employee in the local database and generates a unique shift code for the employee.
# - create_admin: Creates a new admin (either a manager or director) and assigns the appropriate role based on the user type.
# - set_admin_role: Assigns the correct role (manager or director) to the admin user based on their user type.
# - generate_unique_code: Generates a unique shift code for employees, ensuring it is not already in use.
# - check_params: Validates the provided parameters and ensures the required fields are present for user registration.
# - generate_qr_code: Generates a QR code for the user based on their unique shift code and company name.
# - upload_qr_code_to_s3: Uploads the generated QR code image to an S3 bucket.
# - handle_cognito_error: Handles different types of errors from AWS Cognito and returns an appropriate error message.
#
# Constants:
# - Constants::USER_TYPES: A list of valid user types ('employee', 'manager', 'director').


require 'securerandom'

class RegistrationsController < ApplicationController
  # Include the required concerns
  include AccessRequired
  include RolesRequired

  before_action :authenticate_user!

  # ensure only directors, managers, and super admins can create users
  before_action -> { roles_required([ "director", "manager", "super_admin" ]) }

  # Check if email and user_type are present before trying to log in
  before_action :check_params, only: [ :create ]

  # Set up the Cognito service
  before_action :set_cognito_service

  # Set up the File Upload service
  before_action :set_file_upload_service

  # POST /register
  def create
    attributes = user_params.to_h.symbolize_keys
    begin
      # Create the user
      user = create_user(attributes)

      Rails.logger.info("User #{user.id} created successfully")
      render json: { user: user.public_attributes, message: "User created successfully" }, status: :created

    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("An error occurred while creating user: #{e.message}")
      render json: { error: "An error occurred while creating user, please try again" }, status: :bad_request
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      Rails.logger.error("Error creating user: #{e.message}")
      handle_cognito_error(e)
      nil
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

  # Set up the File Upload service for the controller actions
  def set_file_upload_service
    @file_upload_service = FileUploadService.new
  end

  # Set up the user params
  def user_params
    params.permit(:first_name, :last_name, :email, :telephone, :user_type, :branch_id, :area_id,
                  :contract_code, :tax_code, :date_of_birth, :contract_start_date, :contract_end_date)
  end

  # Get the user class based on the user type
  def user_class_for(user_type)
    case user_type
    when "employee" then Employee
    else Admin
    end
  end

  # Create a user based on the user type
  def create_user(attributes)
    user_type = attributes[:user_type]

    begin
      # Wrap the entire operation in a transaction
      user = ActiveRecord::Base.transaction do
        # Generate the password
        password = Utils::PasswordGenerator.generate_password(6)

        # Create the user in the database
        user = case user_type
              when "employee"
                create_employee(attributes)
              when "director", "manager"
                create_admin(attributes, user_type)
              else
                raise "Unknown user type"
              end

        # Call cognito service to register the user
        cognito_response = @cognito_service.register_user(attributes[:email], password)

        # This will only return the user if everything is successful
        user
      end
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      Rails.logger.error("Error registering user in Cognito: #{e.message}")
      raise e
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      raise e
    end

    user
  end


  def create_employee(attributes)
    begin

      employee = Employee.create!(
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
        contract_end_date: attributes[:contract_end_date],
      )

      unique_shift_code = generate_unique_code

      employee.shift_code = unique_shift_code

      user_name = unique_shift_code + "CompanyName"

      # Generate QR code and save it to the employee
      qr_code_base64_img = generate_qr_code(employee, user_name)

      # Decode base64 to bytes
      qr_code_bytes = Utils::Base64Decoder.decode_base64_to_bytes(qr_code_base64_img)

      # Upload the QR code to S3
      upload_qr_code_to_s3(qr_code_bytes, user_name)

      qr_code_url = ENV["S3_USER_BUCKET_URL"] + "#{user_name}.png"

      employee.qr_code_url = qr_code_url

      employee.save!
    
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Error creating employee: #{e.message}")
      raise "Employee creation failed: #{e.message}"
    rescue StandardError => e
      Rails.logger.error("Error creating employee: #{e.message}")
      raise "Employee creation failed: #{e.message}"    
    end

    employee
  end

  def create_admin(attributes, user_type)
    begin
      admin = Admin.create!(
        first_name: attributes[:first_name],
        last_name: attributes[:last_name],
        email: attributes[:email],
        telephone: attributes[:telephone],
        branch_id: attributes[:branch_id]
      )

      set_admin_role(attributes, admin, user_type)
      admin.save!

    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Error creating admin: #{e.message}")
      raise "Admin creation failed: #{e.message}"
    rescue StandardError => e
      Rails.logger.error("Error creating admin: #{e.message}")
      raise "Admin creation failed: #{e.message}"
    end
    admin
  end

  def set_admin_role(attributes, admin, user_type)
    case user_type
    when "manager"
      admin.is_manager = true
      admin.area_id = attributes[:area_id]
    when "director"
      admin.is_director = true
    end
  end

  def generate_unique_code
    max_attempts = 10
    attempts = 0

    while attempts < max_attempts
      code = SecureRandom.uuid.gsub("-", "")[0, 6]
      # Check if the code is unique
      unless Employee.exists?(shift_code: code)
        return code
      end
      attempts += 1
    end

    raise "Unable to generate unique code after #{max_attempts} attempts"
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

    # Define the required parameters based on user type
    required_params = %i[first_name email telephone]
    required_params += [ :contract_start_date, :contract_end_date ] if user_type == "employee"
    required_params += [ :branch_id, :area_id ] if %w[employee manager].include?(user_type)
    required_params += [ :branch_id ] if user_type == "director"

    # Check for any missing parameters
    missing = required_params.reject { |key| params[key].present? }

    if missing.any?
      missing_params = missing.join(", ")
      error_message = "The following required fields are missing: #{missing_params}. Please provide them to proceed."
      return render_error(error_message)
      return
    end

    # Check if email is valid
    unless Utils::EmailValidator.valid?(params[:email])
      return render_error("The email provided is invalid. Please provide a valid email address.")
    end

    # Ensure email uniqueness
    if Employee.find_by(email: params[:email]) || Admin.find_by(email: params[:email])
      return render_error("An account already exists with the email provided. Please use a different email address.")
    end

    if user_type == "employee"
      # validate the date format
      unless Utils::DateValidator.valid?(params[:contract_start_date])
        return render_error("Invalid date format for contract start date. Please provide a valid date in the format 'YYYY-MM-DD'.")
      end

      unless Utils::DateValidator.valid?(params[:contract_end_date])
        return render_error("Invalid date format for contract end date. Please provide a valid date in the format 'YYYY-MM-DD'.")
      end
    end

    # Check if the area belongs to the given branch
    if params[:branch_id] || params[:area_id]
      area_id = params[:area_id]
      branch_id = params[:branch_id]

      unless branch_id.blank? || Branch.exists?(id: branch_id)
        return render_error("The branch does not exist. Please provide a valid branch id.")
      end

      if !area_id.blank?
        unless Area.exists?(id: area_id)
          return render_error("The area does not exist. Please provide a valid area id.")
        end

        unless Area.joins(:branches).where(id: area_id, branches: { id: branch_id }).exists?
          return render_error("The area does not belong to the specified branch.")
        end
      end

      # check if the user belongs to the branch they are trying to assign a user to
      check_current_user_branch_and_area(branch_id, area_id)
    end
  end

  def check_current_user_branch_and_area(branch_id, area_id)
    current_user = @current_user
    current_user_email = current_user["email"]

    # retrieve the admin changing the password
    admin = Admin.find_by(email: current_user_email)

    # check if the admin exists
    unless admin
      render_error("Admin not found", :not_found)
    end

    # check if the admin belongs to the branch
    if admin.is_director || admin.is_manager
      unless admin.branch_id == branch_id
        render_error("You are not authorized to assign users to the specified branch.", :unauthorized)
      end
    end

    if area_id && admin.is_manager
      # check if the manager belongs to the area
      unless admin.area_id == area_id
        render_error("You are not authorized to assign users to the specified area.", :unauthorized)
      end
    end
  end
  
  def render_error(message, status = :bad_request)
      render json: { error: message }, status: status
  end

  def generate_qr_code(employee, user_name)
    begin
      
      # Generate the QR code base64 string
      qr_code_base64_img = Utils::QrCodeGenerator.generate_qr_code(user_name)

      Rails.logger.info("QR Code generated successfully for: #{user_name}")

      qr_code_base64_img
    rescue StandardError => e
      Rails.logger.error("Error generating QR code: #{e.message}")
      raise
    end
  end

  def upload_qr_code_to_s3(qr_code_bytes, file_name)
    begin
      # Upload the QR code image to S3
      response = @file_upload_service.upload_file("user", qr_code_bytes, "#{file_name}.png", "image/png")

      Rails.logger.info("QR Code uploaded successfully: #{file_name}.png")
    rescue StandardError => e
      Rails.logger.error("Error uploading QR code to S3: #{e.message}")
      raise
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
