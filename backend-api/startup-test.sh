#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Print a message
echo "Checking and applying database migrations for test environment..."

# Run database migrations for the test database
# drop the test database, create a new one, and run all migrations
bundle exec rails db:test:prepare

# Print a message indicating completion
echo "Database migrations applied."


# Run tests
echo "Running tests..."
# Rails will use one worker to run the tests, this will prevent multiple database connections/migrations from running at the same time
PARALLEL_WORKERS=1 bundle exec rails test
echo "Tests complete."
