#!/bin/bash

# Exit early if any command fails
set -e

# Print all commands
set -x

pwd

# load .env file
# Define the path to the .env file
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
    echo "Loading environment variables from $ENV_FILE..."
    # Export the variables in the .env file
    set -a
    source "$ENV_FILE"
    set +a
    echo "Environment variables loaded."
else
    echo "Error: $ENV_FILE file not found."
    exit 1
fi

echo $goaccess_version
exit 0

# ensure you're not running it on local machine
if [ -z "$CI" ] || [ -z "$GITHUB_REF" ]; then
    echo "Running on a local machine! Exiting!"
    exit 127
else
    echo "Running on CI"
fi

IMAGE_NAME=caprover/goacess

if [ ! -f ./package-lock.json ]; then
    echo "package-lock.json not found!"
    exit 1
fi

# BRANCH=$(git rev-parse --abbrev-ref HEAD)
# On Github the line above does not work, instead:
BRANCH=${GITHUB_REF##*/}
echo "on branch $BRANCH"
if [[ "$BRANCH" != "release" ]]; then
    echo 'Not on release branch! Aborting script!'
    exit 1
fi

## Building frontend app
ORIG_DIR=$(pwd)

sudo apt-get update && sudo apt-get install qemu-user-static
# docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker run --rm --privileged tonistiigi/binfmt --install all
# export DOCKER_CLI_EXPERIMENTAL=enabled
docker buildx ls
docker buildx rm mybuilder || echo "mybuilder not found"
docker buildx create --name mybuilder
docker buildx use mybuilder

# docker buildx build --platform linux/arm -t $IMAGE_NAME:$CAPROVER_VERSION -t $IMAGE_NAME:latest  -f dockerfile-captain.edge --push .
docker buildx build --platform linux/amd64,linux/arm64,linux/arm -t $IMAGE_NAME:$CAPROVER_VERSION -t $IMAGE_NAME:latest -f Dockerfile.goaccess --push .

# docker build -t $IMAGE_NAME:$CAPROVER_VERSION -t $IMAGE_NAME:latest  -f dockerfile-captain.edge .
# docker push $IMAGE_NAME:latest
# docker push $IMAGE_NAME:$CAPROVER_VERSION