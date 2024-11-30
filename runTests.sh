#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Start the containers and stop all if any container exits
echo "Starting the containers..."
docker-compose -f docker-compose.test.yml up --build --abort-on-container-exit

# Bring down the entire Docker Compose setup
echo "Bringing down all containers..."
docker-compose -f docker-compose.test.yml down

echo "All containers terminated."