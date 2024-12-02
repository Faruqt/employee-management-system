# lib/utils/email_validator.rb

module Utils
  class EmailValidator
    def self.valid?(email)
      # Basic email validation regex (you can use more advanced ones)
      email =~ /\A[^@\s]+@([^@\s]+\.)+[^@\s]+\z/
    end
  end
end