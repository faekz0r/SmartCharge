#!/bin/bash

# enable debugging
set -v -x -e
# set -o errexit


# check if already running and exit if true
if ! mkdir /tmp/SmartCharge.lock 2>/dev/null; then
    echo "SmartCharge is already running. Exiting" >&2
    exit 1
fi

trap 'rm -rf /tmp/SmartCharge.lock' EXIT

source user_vars.sh
source system_vars.sh
source functions.sh



# timestamp last run
echo "$(LC_ALL="et_EE.UTF-8" date "+%T %A %d/%m")" > last_ran_date

get_prices

sort_prices

refresh_bearer_token

# decide if charging time is to be calculated by time_to_charge function or taken from user variables
if [[ -n "$charge_for_hours" ]] && [ "$charge_for_hours" -gt 0 ]; then
	seconds_to_limit=$(echo "$charge_for_hours * 3600" | bc)
	set_charge_limit_to_max
else
	time_to_charge
fi

echo "sorted_prices.csv:"
cat sorted_prices.csv

keep_charging_hours_only

echo "resorted_prices.csv:"
cat resorted_prices.csv

if [ "$charge_for_hours" -eq "0" ] || [ -z "$charge_for_hours" ]; then

#	wake_tesla
#	sleep 15

#	check_charge_state
#	sleep 3

	if [ $((battery_level + no_charge_buffer)) -ge "$charge_limit" ]; then
		echo "No need to charge, since charge limit is at: $charge_limit%"
		echo "and battery level is at: $battery_level%"
		exit
	fi

fi


echo "\nseconds_to_limit:" "$seconds_to_limit\n"
echo "\ncharge_for_hours:" "$charge_for_hours\n"

for i in $(seq 1 "$charge_for_hours"); do
	cheap_hour_start_csv=$(sed -n "$i"{p} resorted_prices.csv)
	cheap_hour_start_stripped=$(echo "$cheap_hour_start_csv" | awk -F "," '{ print $1 }')

	next_cheap_hour_start_csv=$(sed -n $((i + 1)){p} resorted_prices.csv)
	next_cheap_hour_start_stripped=$(echo "$next_cheap_hour_start_csv" | awk -F "," '{ print $1 }')

	sleep_seconds=$((cheap_hour_start_stripped - $(date +%s) ))

#	echo "cheap_hour_start_stripped in unix time: $cheap_hour_start_stripped human time: $(date -d "@""$cheap_hour_start_stripped")"
	echo "cheap hour start: $(date -d "@""$cheap_hour_start_stripped")"
	echo "cycle nr: $i of $charge_for_hours"
	echo "time is: $(date)"

	# check if we need to sleep till charge_start and start the sleep if needed
	if [ $sleep_seconds -gt 0 ]; then
		sleep $sleep_seconds
	fi

	refresh_bearer_token

	wake_tesla

	charge_start

	# sleep till next hour to start the cycle again
	sleep_till_next_hour

	# check if any hours left to charge
	if [ -z "$next_cheap_hour_start_stripped" ]; then
		charge_stop
		echo "Done charging"
		exit 0
	fi

	# check if we need to stop charging till next cheap hour
	seconds_to_next_cheap=$(((next_cheap_hour_start_stripped) - $(date +%s)))
	if [ $seconds_to_next_cheap -gt 60 ]; then
		charge_stop
	fi

done

cp main.log "logs/main.log.$(date '+%Y-%m-%d_%H-%M-%S')"
