class WelcomeController < ApplicationController
  def index
    render json: { message: "Welcome to the employee management system API! Your request was successful." }, status: :ok
  end
end
