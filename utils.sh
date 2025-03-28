#!/usr/bin/env bash
set -e
WAS_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$WAS_DIR"

# Test for local environment file and use any overrides
if [ -r .env ]; then
    echo "Using configuration overrides from .env file"
    . .env
else
    echo "Using default configuration values"
    touch .env
fi

#Import source the .env file
set -a
source .env

# Which docker image to run
IMAGE=${IMAGE:-willow-application-server}

# HTTPS Listen port
LISTEN_PORT_HTTPS=${LISTEN_PORT_HTTPS:-19000}

# UI Listen port
UI_LISTEN_PORT=${UI_LISTEN_PORT:-8501}

# API Listen Port
API_LISTEN_PORT=${API_LISTEN_PORT:-8502}

# Log level - acceptable values are debug, info, warning, error, critical. Suggest info or debug.
LOG_LEVEL=${LOG_LEVEL:-debug}

# Listen IP
LISTEN_IP=${LISTEN_IP:-0.0.0.0}

TAG=${TAG:-latest}
NAME=${NAME:was}

# Reachable WAS IP for the "default" interface
WAS_IP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+')

TAG=${TAG:-latest}
NAME=${NAME:was}

set +a

if [ -z "$WAS_IP" ]; then
    echo "Could not determine WAS IP address - you will need to add it to .env"
else
    echo "WAS IP is $WAS_IP"
fi

set +a

dep_check() {
    return
}

freeze_requirements() {
    if [ ! -f /.dockerenv ]; then
        echo "This script is meant to be run inside the container - exiting"
        exit 1
    fi

    # Freeze
    pip freeze > requirements.txt
}

build-docker() {
    docker build -t "$IMAGE":"$TAG" .
}

gen-tz() {
    curl --output gen-tz.py https://raw.githubusercontent.com/nayarsystems/posix_tz_db/master/gen-tz.py
    python3 gen-tz.py --json > tz.json
}

shell() {
    docker run -it -v $WAS_DIR:/app -v $WAS_DIR/cache:/root/.cache -v willow-application-server_was-storage:/app/storage "$IMAGE":"$TAG" \
        /usr/bin/env bash
}

case $1 in

build-docker|build)
    gen-tz
    build-docker
;;

freeze-requirements)
    freeze_requirements
;;

start|run|up)
    dep_check
    shift
    docker compose up --remove-orphans "$@"
;;

stop|down)
    dep_check
    shift
    docker compose down "$@"
;;

shell|docker)
    shell
;;

*)
    dep_check
    echo "Passing unknown argument directly to docker compose"
    docker compose "$@"
;;

esac
