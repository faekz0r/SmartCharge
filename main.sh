#!/bin/bash
set -v -x -e
# set -o errexit
source user_vars.sh
source system_vars.sh
source functions.sh


get_prices

sort_prices

# decide if charging time is to be calculated by time_to_charge function or taken from user variables
if [ $charge_for_hours > 0 ];
then
	seconds_to_limit=$(echo "$charge_for_hours * 3600" | bc)
else
	time_to_charge
fi

echo "sorted_prices.csv:"
cat sorted_prices.csv

keep_charging_hours_only

echo "resorted_prices.csv:"
cat resorted_prices.csv

if [ -z "$charge_for_hours" ]; then

	wake_tesla
	sleep 15


	check_charge_state
	sleep 3

	if [ $(( $battery_level + $no_charge_buffer )) -ge $charge_limit ]; then
		echo "No need to charge, since charge limit is at: $charge_limit%"
		echo "and battery level is at: $battery_level%"
		exit
	fi

fi

echo "seconds_to_limit:" $seconds_to_limit
echo "charge_for_hours:" $charge_for_hours

for i in $(seq 1 $charge_for_hours)
do
	cheap_hour_start_csv=$( sed -n $i{p} resorted_prices.csv )
	cheap_hour_start_stripped=$( echo $cheap_hour_start_csv | awk -F "," '{ print $1 }' )

	next_cheap_hour_start_csv=$( sed -n $((i+1)){p} resorted_prices.csv )
	next_cheap_hour_start_stripped=$( echo $next_cheap_hour_start_csv | awk -F "," '{ print $1 }' )

	sleep_seconds=$(( $cheap_hour_start_stripped - $(date +%s) ))

	echo "cheap_hour_start_stripped:" $cheap_hour_start_stripped
	echo "cycle nr:" $i
	echo "time is:" $(date)

	# check if we need to sleep till charge_start and start the sleep if needed
	if [ $sleep_seconds -gt 0 ]; then
		sleep $sleep_seconds
	fi
	
	# check if we need to start charging
#	if [ -z "$cheap_hour_start_stripped" ]; then
#		echo "Done charging"
#                exit 0
#	else
		wake_tesla
		charge_start
#	fi

	# sleep till next hour to start the cycle again
	sleep $(seconds_until_next_hour)

	# check if any hours left to charge
	if [ -z "$next_cheap_hour_start_stripped" ]; then
		charge_stop
		echo "Done charging"
		exit 0
	fi

	# check if we need to stop charging till next cheap hour
	seconds_to_next_cheap=$(( ( $next_cheap_hour_start_stripped ) - $(date +%s) )) 
	if [ $seconds_to_next_cheap -gt 60 ]; then
		charge_stop
	fi
	
done
