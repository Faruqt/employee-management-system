# WelcomeController handles the welcome message for the employee management system API.
#
# Actions:
#   - index: Renders a JSON response with a welcome message and a status of OK.
class WelcomeController < ApplicationController
  def index
    render json: { message: "Welcome to the employee management system API! Your request was successful." }, status: :ok
  end
end
