# DEPLOYMENT INSTRUCTIONS FOR LAMBDA FUNCTIONS

## Automated Deployment

The deployment process is automatically triggered when you push code to GitHub. Ensure that your repository is connected to the appropriate AWS Lambda function via CI/CD pipelines (e.g., GitHub Actions, AWS CodePipeline, etc.).

## Manual Deployment

1. Zip the deployable files:
    ```bash
    zip -r lambda_function.zip *
    ```

2. Upload the zipped file to the Lambda function on AWS:
   - Navigate to the Lambda function in the AWS Console.
   - In the "Function code" section, select "Upload from" and choose the `.zip` file you created.
   - Click "Save" to deploy the new version.
