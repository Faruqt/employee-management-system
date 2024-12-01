class WelcomeController < ApplicationController
  def index
    render json: { message: "Welcome to the shift management system API! Your request was successful." }, status: :ok
  end
end
