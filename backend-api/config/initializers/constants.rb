# config/initializers/constants.rb

module Constants
  # Date formats
  DATE_FORMAT = "%Y-%m-%d".freeze
  DATETIME_FORMAT = "%Y-%m-%d %H:%M:%S".freeze

  # Pagination settings
  DEFAULT_PER_PAGE = 20

  # User types
  USER_TYPES = %w[employee manager director].freeze
end
