#!/usr/bin/env bash

set -e
docker build -t keyah:latest --progress=plain .
docker run -it --rm --entrypoint /bin/bash keyah:latest
