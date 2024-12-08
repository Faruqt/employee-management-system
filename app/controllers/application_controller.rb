class ApplicationController < ActionController::API
  # Catch RoutingError and render a custom message
  rescue_from ActionController::RoutingError, with: :route_not_found

  def route_not_found(exception = nil)
    if exception
        Rails.logger.error("RoutingError caught: #{exception.message}")
    else
        Rails.logger.error("RoutingError caught")
    end

    # Render the custom 404 message
    render json: { error: "Route not found, please check the URL or try another route" }, status: :not_found
  end
end
