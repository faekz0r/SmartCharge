#!/bin/bash

# enable debugging
set -v -x -e
# set -o errexit

check_dependencies() {
    for cmd in jq bc awk sed; do
        if ! command -v $cmd &> /dev/null; then
            echo "$cmd is not installed. Exiting."
            exit 1
        fi
    done
}

# Check Dependencies Before Proceeding
check_dependencies

# Load Other Functions from functions.sh
source functions.sh

# Load vars
source user_vars.sh
source system_vars.sh

initialize_lock
update_last_run_timestamp

get_prices
sort_prices
refresh_bearer_token

decide_charge_time

echo "sorted_prices.csv:"
cat sorted_prices.csv

keep_charging_hours_only

echo "resorted_prices.csv:"
cat resorted_prices.csv

if [ "$charge_for_hours" -eq "0" ] || [ -z "$charge_for_hours" ]; then
    check_battery_level
fi

echo "\nseconds_to_limit:" "$seconds_to_limit\n"
echo "\ncharge_for_hours:" "$charge_for_hours\n"

charge_cycle

backup_log
