# lib/utils/password_generator.rb

module Utils
  module PasswordGenerator
    def self.generate_password(length)
      # Generate a random password of the specified length
      password_string = rand(10**(length - 1)..(10**length - 1)).to_s
      password_string
    end
  end
end
