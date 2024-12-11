require 'base64'

module Utils
    module Base64Decoder
        def self.decode_base64_to_bytes(base64_string)
            # Decode the base64 string to bytes

            decoded_bytes = Base64.decode64(base64_string)

            decoded_bytes
        end
    end
end