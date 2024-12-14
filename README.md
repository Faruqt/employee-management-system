# EMPLOYEE MANAGEMENT SYSTEM MONO REPO

This is a mono repository for the Employee Management System project. It includes the following components:

- **Backend API**: A RESTful API designed to manage organizations, branches, areas, roles, and the assignment of employees to these structures. It includes endpoints to efficiently create and manage employees, assign roles such as directors, managers, and employees, and facilitate seamless organizational operations within a single app.
- **Lambda Functions**: A custom AWS Lambda function that handles sending custom authentication messages, such as account creation and password reset notifications.

## Project Structure
- `backend-api/`: Contains the backend API implementation.
- `lambda-functions/`: Contains various Lambda functions, including the custom authentication message lambda.

## Getting Started
### Backend API
The backend API is built using Ruby on Rails. To get started, follow the instructions in the `backend-api/README.md`.

### Lambda Functions
To learn how to deploy and manage Lambda functions, refer to the `lambda-functions/README.md`.

## Requirements
- Ruby on Rails
- AWS account (for managing Lambda functions)


## Installation

1. Clone the repository:
    ```bash
    git clone https://github.com/Faruqt/employee-management-system.git
    ```

2. Install dependencies for the backend API:
    ```bash
    cd backend-api
    bundle install
    ```

3. Install dependencies for Lambda functions (if any):
    ```bash
    cd lambda-functions
    # Implement code changes and deploy as per the instructions in the README for the specific lambda function of interest
    ```