# lib/utils/qr_code_generator.rb

require "rqrcode"
require "chunky_png"
require "base64"

module Utils
    module QrCodeGenerator
        def self.generate_qr_code(employee_id)
            # Path to the logo image (ensure this path is correct for your environment)
            logo_path = Rails.root.join("app/assets/images/company_logo.png")

            # Generate QR code
            qr = RQRCode::QRCode.new(employee_id, level: :h, size: 10)

            # Convert QR code to an image
            qr_code_image = qr.as_png(size: 300, border_modules: 4)

            # Load the logo image
            logo_image = ChunkyPNG::Image.from_file(logo_path)

            # Resize the logo image
            logo_size = (qr_code_image.width * 0.20).to_i
            logo_image = logo_image.resize(logo_size, logo_size)

            # Convert the QR code PNG (from RQRCode) to a ChunkyPNG image
            qr_code_image = ChunkyPNG::Image.from_blob(qr_code_image.to_s)

            # Calculate the position to center the logo on the QR code
            logo_position_x = (qr_code_image.width - logo_image.width) / 2
            logo_position_y = (qr_code_image.height - logo_image.height) / 2

            # Composite the logo onto the QR code
            qr_code_image.compose!(logo_image, logo_position_x, logo_position_y)

            # Convert the image to Base64 string
            img_base64 = Base64.encode64(qr_code_image.to_blob)

            img_base64
        end
    end
end
