#!/usr/bin/env bash

timeout=10
time_elapsed=0

service postgresql stop

until [ $(pgrep postgres | wc -l) -eq 0 ] || [ $time_elapsed -eq $timeout ]; do
  echo "Waiting for Postgres to stop..."
  sleep 1
  time_elapsed=$((time_elapsed+1))
done

if [ $time_elapsed -eq $timeout ]; then
  echo "Timeout reached, Postgres did not stop within $timeout seconds"
  exit 1
fi
