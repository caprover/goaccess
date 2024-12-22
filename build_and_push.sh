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

replaceVariablesInDockerfile() {
    local variables_string="$1" # Comma-separated list of variables
    local file="Dockerfile.goaccess"

    # Check if the variables string is provided
    if [ -z "$variables_string" ]; then
        echo "Error: Variables string must be provided."
        echo "Usage: replace_variables \"var1,var2\""
        return 1
    fi

    # Split the variables string into an array
    IFS=',' read -r -a variables <<<"$variables_string"

    # Iterate over the variables and replace placeholders
    for var in "${variables[@]}"; do
        local value
        value="${!var}"

        if [ -z "$value" ]; then
            echo "Error: Environment variable $var is not set."
            return 1
        fi

        sed -i "s/\$$var/$value/g" "$file"
    done

}

replaceVariablesInDockerfile goaccess_version

# ensure you're not running it on local machine
if [ -z "$CI" ] || [ -z "$GITHUB_REF" ]; then
    echo "Running on a local machine! Exiting!"
    exit 127
else
    echo "Running on CI"
fi

IMAGE_NAME=caprover/goaccess

# BRANCH=$(git rev-parse --abbrev-ref HEAD)
# On Github the line above does not work, instead:
BRANCH=${GITHUB_REF##*/}
echo "on branch $BRANCH"
if [[ "$BRANCH" != "release" ]]; then
    echo 'Not on release branch! Aborting script!'
    exit 1
fi

sudo apt-get update && sudo apt-get install qemu-user-static
# docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker run --rm --privileged tonistiigi/binfmt --install all
# export DOCKER_CLI_EXPERIMENTAL=enabled
docker buildx ls
docker buildx rm mybuilder || echo "mybuilder not found"
docker buildx create --name mybuilder
docker buildx use mybuilder

# docker buildx build --platform linux/arm -t $IMAGE_NAME:$CAPROVER_VERSION -t $IMAGE_NAME:latest  -f dockerfile-captain.edge --push .
docker buildx build --platform linux/amd64,linux/arm64 -t $IMAGE_NAME:$goaccess_version -t $IMAGE_NAME:latest -f Dockerfile.goaccess --push .
# ,linux/arm is not available for allinurl/goaccess
