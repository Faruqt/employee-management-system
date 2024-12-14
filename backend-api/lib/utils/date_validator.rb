# lib/utils/date_validator.rb

module Utils
    module DateValidator
        def self.valid?(date)
            # Date validation regex (you can use more advanced ones)
            date =~ /\A\d{4}-\d{2}-\d{2}\z/
        end
    end
end
