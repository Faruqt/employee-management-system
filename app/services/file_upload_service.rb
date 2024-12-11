# app/services/file_upload_service.rb
require 'aws-sdk-s3'

class FileUploadService
    def initialize
        @client = Aws::S3::Client.new
        @user_bucket_name = ENV["S3_USER_BUCKET_NAME"]
    end
    
    def upload_file(source, file_object, object_name, mime_type)
        Rails.logger.info("Uploading file: #{object_name}")

        user_bucket_name = nil
        if source == "user"
            user_bucket_name = @user_bucket_name
        end

        # Check if the user bucket exists
        unless user_bucket_name 
            Rails.logger.error("User bucket does not exist")
            raise "User bucket does not exist"
        end
        
        begin
            # Upload the file to S3
            response = @client.put_object(
                bucket: user_bucket_name,
                key: object_name,
                body: file_object,  
                content_type: mime_type 
            )
        
            Rails.logger.info("File uploaded successfully: #{object_name} to bucket: #{user_bucket_name}")
            true
        rescue Aws::S3::Errors::ServiceError => e
            Rails.logger.error("Error uploading file: #{e.message}")
            raise
        end
    end
end