# BACKEND API

The Backend API is a RESTful service for managing organizations, branches, areas, create roles and assign directors, managers and employees to respective areas and branches. It provides endpoints to seamlessly manage your organization from within a single app.

## Setup

### Prerequisites

Ensure you have the following tools installed:

- **Ruby** (version specified in `.ruby-version`)
- **Ruby on Rails** (version specified in `Gemfile`)
- **PostgreSQL** database
- **Docker-Compose** (for managing containerized services)
- **Docker-Desktop** (to run containers locally)

### Install Dependencies

1. Install the required Ruby version using `rbenv` or `rvm` (if not already installed).
2. Install the necessary Ruby gems:
    ```bash
    bundle install
    ```

### Environment Variables

Set up the necessary environment variables for your local development environment. 

1. Copy the `env.sample` file to `.env`:
    ```bash
    cp env.sample .env
    ```
2. Update the `.env` file with the appropriate values for your environment.


### Starting the Application

To start the application locally, use Docker-Compose to bring up the backend services:

1. Run the following command:
    ```bash
    docker-compose -f docker-compose.dev.yml up
    ```
    This will start the API and PostgreSQL database services.

2. After the services are up, your API should be accessible at `http://127.0.0.1:3005`.


## Testing
To run the test suite, use the following command:

1. Run all tests:
  ```sh
  bash run-tests.sh
  ```
This command will spin up a Docker environment that mirrors your development setup, ensuring that tests are run in an environment similar to your local development environment. Any failing tests will be reported as feedback.


## Contributions

We follow best practices for code quality and maintain consistency through the use of `rubocop` for code formatting and linting.

### Run `rubocop` for Code Quality

To ensure code quality, you can run rubocop locally to evaluate the linting and formatting of your contribution.

```bash
bundle exec rubocop -a
```

`Automatic Fixes`: When you make a contribution, the CI/CD workflow will automatically attempt to fix any issues related to code formatting and style that it can handle.

`Workflow Failures`: If the workflow cannot automatically fix the issues, it will fail and display the details in the workflow logs.

`Fixing Issues`: Review the workflow logs to identify the issues. You’ll need to fix these issues locally based on the feedback provided.

`Re-submit`: After addressing the issues, push your changes to the repository again. The workflow will rerun and verify that the issues have been resolved.

By following these steps, you help ensure that all code contributions meet our quality standards.

