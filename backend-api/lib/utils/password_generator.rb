# lib/utils/password_generator.rb

module Utils
  module PasswordGenerator
    def self.generate_password(length)
      # Generate a random password of the specified length with numbers
      password_string = rand(10**(length - 1)..(10**length - 1)).to_s

      # Add a random lowercase character to the password
      password_string += (("a".."z").to_a.sample)

      password_string
    end
  end
end
