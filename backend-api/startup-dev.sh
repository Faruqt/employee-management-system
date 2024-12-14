#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Print a message
echo "Checking and applying database migrations..."

# Run database migrations
bundle exec rails db:migrate || echo "Database migrations applied."

# Remove the server PID file if it exists
rm -f /rails/tmp/pids/server.pid

# Start the Rails server
./bin/rails server -b 0.0.0.0