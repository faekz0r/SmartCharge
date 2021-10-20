#!/bin/bash
set -v -x -e
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


wake_tesla
sleep 3

check_charge_state
sleep 3

if [ "$battery_level" -ge "$charge_limit" ]; then
	echo "No need to charge, since charge limit is at: $charge_limit%"
	echo "and battery level is at: $battery_level%"
	exit
fi


echo "seconds_to_limit:" $seconds_to_limit
echo "charge_for_hours:" $charge_for_hours

for i in $(seq 1 $charge_for_hours);
do
	cheap_hour_start_csv=$(sed -n $i{p} resorted_prices.csv)
	cheap_hour_start_stripped=$( echo $cheap_hour_start_csv | awk -F "," '{ print $1 }' )
	sleep_seconds=$(( $cheap_hour_start_stripped - $(date +%s) ))
	echo "cheap_hour_start_stripped:" $cheap_hour_start_stripped
	
	if [ $sleep_seconds -ge 0 ]; then
		sleep $sleep_seconds
	fi

	wake_tesla
	charge_start
	sleep $(( $(date +%s) - $cheap_hour_start_stripped ))
	charge_stop
done

# charging
