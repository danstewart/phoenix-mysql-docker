#!/usr/bin/env bash

set -e

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --app) app=$2; shift ;;
        -v|--verbose) verbose=1 ;;
        -h|--help) help=1 ;;
        --) shift; break ;;
    esac

    shift
done

if [[ -z $app || $help == 1 ]]; then
    echo "Usage: ./init.sh --app <app_name> [--verbose] [--help]"
    echo ""
    echo "Will initialise a new phoenix application and start the container on http://localhost:4000"
    echo "  --app:     The name of the phoenix app"
    echo "  --verbose: Display all command output"
    echo "  --help:    Display this help text and exit"

    exit 0
fi

output=/dev/null
if [[ -n $verbose && $verbose == 1 ]]; then
    output=/dev/stdout
fi

function generate_password {
    < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32}
}

echo "Generating .env file..."
[[ -f .env ]] && rm -f .env
touch .env
echo "MYSQL_DATABASE=${app}" >> .env
echo "MYSQL_USER=app" >> .env
echo "MYSQL_PASSWORD=$(generate_password)" >> .env
echo "MYSQL_ROOT_PASSWORD=$(generate_password)" >> .env

echo "Building containers..."
docker-compose build --quiet >$output 2>&1

echo "Generating new phoenix app..."
echo y | docker-compose run app mix phx.new . --app "$app" --database mysql >$output 2>&1
docker-compose run app mix deps.get >$output 2>&1

# Tweak the dev.exs config to read from the environment file
echo "Rejigging the config..."
perl -p -i -e 's/username: .*,/username: System.get_env("MYSQL_USER"),/' src/config/dev.exs
perl -p -i -e 's/password: .*,/password: System.get_env("MYSQL_PASSWORD"),/' src/config/dev.exs
perl -p -i -e 's/database: .*,/database: System.get_env("MYSQL_DATABASE"),/' src/config/dev.exs
perl -p -i -e 's/hostname: .*,/hostname: "db",/' src/config/dev.exs
perl -p -i -e 's/ip: \{127, 0, 0, 1\}/ip: {0, 0, 0, 0}/' src/config/dev.exs

echo "Initialising database..."
docker-compose run app mix ecto.create >$output 2>&1

echo "Starting container..."
docker-compose up -d --build app >$output 2>&1

echo -e "\nDone! Your phoenix app should now be running on http://localhost:4000"
