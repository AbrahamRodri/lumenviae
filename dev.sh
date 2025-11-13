#!/bin/bash
# Load environment variables from .env and start Phoenix server

if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
  echo "Loaded environment variables from .env"
else
  echo "Warning: .env file not found"
fi

mix phx.server
