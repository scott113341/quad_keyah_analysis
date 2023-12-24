#!/usr/bin/env bash

set -e

timeout=10
time_elapsed=0

service postgresql start

until nc -z localhost 5432 || [ $time_elapsed -eq $timeout ]; do
  echo "Waiting for Postgres to start..."
  sleep 1
  time_elapsed=$((time_elapsed+1))
done

if [ $time_elapsed -eq $timeout ]; then
  echo "Timeout reached, Postgres did not start within $timeout seconds"
  exit 1
fi
