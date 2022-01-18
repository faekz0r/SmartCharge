#!/bin/bash

get_prices () {
	current_hour=$( date '+%H')
	current_epoch=$( date -d 'today '$current_hour'' +%s )
	current_epoch_tomorrow=$( date -d 'tomorrow '$current_hour'' +%s )
	start_epoch_today=$( date -d 'today '$start_hour'' +%s )
	start_epoch_tomorrow=$( date -d 'tomorrow '$start_hour'' +%s )
	end_epoch_today=$( date -d 'today '$end_hour'' +%s)
	end_epoch_tomorrow=$( date -d 'tomorrow '$end_hour'' +%s )
	
	echo "current_hour:" $current_hour
	if [ $start_hour = $end_hour ]; then
		start_epoch_time=$current_epoch
		end_epoch_time=$current_epoch_tomorrow
	elif [ $start_hour > $end_hour ]; then
		if [ $current_hour -ge $start_hour ]; then
			start_epoch_time=$current_epoch
		else # $current_hour < $start_hour
			if [ $current_hour < $end_hour ]; then
				start_epoch_time=$current_epoch
			else
				start_epoch_time=$start_epoch_today
			fi
		fi	
		end_epoch_time=$end_epoch_tomorrow
	else # $start_hour < $end_hour
		if [ $current_hour < $end_hour ]; then
			end_epoch_time=$end_epoch_today
			if [ $current_hour -ge $start_hour ]; then
				start_epoch_time=$current_epoch
			else
			# $current_hour < $start_hour
				start_epoch_time=$start_epoch_today
			fi
		else # $current_hour >= $end_hour
			start_epoch_time=$start_epoch_tomorrow
			end_epoch_time=$end_epoch_tomorrow
		fi
	fi
	
	start_year=$(TZ=GMT date -d @$start_epoch_time +%Y)
	start_month=$(TZ=GMT date -d @$start_epoch_time +%m)
	start_day=$(TZ=GMT date -d @$start_epoch_time +%d)
	start_hour_gmt=$(TZ=GMT date -d @$start_epoch_time +%H)
	
	end_year=$(TZ=GMT date -d @$end_epoch_time +%Y)
	end_month=$(TZ=GMT date -d @$end_epoch_time +%m)
	end_day=$(TZ=GMT date -d @$end_epoch_time +%d)
	end_hour_gmt=$(TZ=GMT date -d @$end_epoch_time +%H)
	
	prices=$($elering_api_curl$start_year-$start_month-$start_day"%20"$start_hour_gmt"%3A00&end="$end_year-$end_month-$end_day"%20"$end_hour_gmt"%3A00" | jq -r '.data.ee | map([(.timestamp|tostring), (.price|tostring)] | join(", ")) | join("\n")')
	
	echo "$prices" > 'prices.csv'
}

sort_prices () {
sort -k2 -n -t, prices.csv > sorted_prices.csv

# fetch cheapest hour price only for max_price_for_high_limit
cheapest_hour_price=$(head -n1 sorted_prices.csv | cut -d ',' -f2)
}

keep_charging_hours_only () {
cat sorted_prices.csv | head -n $charge_for_hours > cheap_sorted_prices.csv
# sort by time
sort -k1 -n -t, cheap_sorted_prices.csv > resorted_prices.csv
}

now_epoch() { date +%s; }
next_hour_epoch() { date -d $(date -d "next hour" '+%H:00:00') '+%s'; }
seconds_until_next_hour() { echo $(( 3600 - $(date +%s) % 3600 )); }

wake_tesla () {
until curl --request POST -H 'Authorization: Bearer '$bearer_token'' $tesla_api_url$tesla_vehicle_id"/wake_up" | jq .response.state | grep -q "online";
do
	sleep 5;
	curl --request POST -H 'Authorization: Bearer '$bearer_token'' $tesla_api_url$tesla_vehicle_id"/wake_up"
	sleep 10;
done
echo "Tesla awoken"
}

check_charge_state () {
sleep 5
while [[ -z $battery_state_json ]] || [[ $(echo $battery_state_json | jq .response) = 'null' ]];
do
	battery_state_json=$(curl --request GET -H 'Authorization: Bearer '$bearer_token'' $tesla_api_url$tesla_vehicle_id/data_request/charge_state)
	sleep 10
done

	battery_level=$(echo $battery_state_json | jq .response.battery_level)
	charge_limit=$(echo $battery_state_json | jq .response.charge_limit_soc)
	charger_phases=$(echo $battery_state_json | jq .response.charger_phases)
	charging_amps=$(echo $battery_state_json | jq .response.charge_current_request)
	if [ $charger_phases -gt "1" ]
	then
		charging_power=$(echo "$charging_amps * 3 * 230 / 1000" | bc)
	else
		charging_power=$(echo "$charging_amps * 230 / 1000" | bc)
	fi

}

set_charge_limit_to_max() {
	wake_tesla
	sleep 5

	# loop as long as we get response 200
	while [[ "$(curl --request POST -H 'Authorization: Bearer '$bearer_token'' -H "Content-Type: application/json" --data '{"percent" : "'$max_charge_limit'"}' -o /dev/null -s -w "%{http_code}" $tesla_api_url$tesla_vehicle_id/command/set_charge_limit )" != "200" ]];
		do sleep 5;
	done;
#	curl --request POST -H 'Authorization: Bearer '$bearer_token'' $tesla_api_url$tesla_vehicle_id/command/set_charge_limit?percent=':''$max_charge_limit'
}

set_charge_limit_to_min() {
        wake_tesla
        sleep 5

        # loop as long as we get response 200
	while [[ "$(curl --request POST -H 'Authorization: Bearer '$bearer_token'' -H "Content-Type: application/json" --data '{"percent" : "'$min_charge_limit'"}' -o /dev/null -s -w "%{http_code}" $tesla_api_url$tesla_vehicle_id/command/set_charge_limit)" != "200" ]];
                do sleep 5;
        done;
#       curl --request POST -H 'Authorization: Bearer '$bearer_token'' $tesla_api_url$tesla_vehicle_id/command/set_charge_limit?percent=':''$max_charge_limit'
}


time_to_charge() {
	wake_tesla
	check_charge_state
	

	# change cheapest_hour_price to integer
	printf -v cheapest_hour_price_int %.0f "$cheapest_hour_price"

	# if cheapest hour is cheap, set charge limit to max else set charge limit to min
	if [ "$cheapest_hour_price_int" -lt "$max_price_for_high_limit" ]; then
		set_charge_limit_to_max
		check_charge_state
	else
		set_charge_limit_to_min
                check_charge_state
	fi

	one_hour_percentage=$(echo "scale = 2; $charging_power * 100 / $battery_size" | bc)
	seconds_to_limit=$(echo "scale = 2; ($charge_limit - $battery_level) / $one_hour_percentage * 3600" | bc )
	charge_for_hours=$(echo "a=$seconds_to_limit; b=3600; if ( a%b ) a/b+1 else a/b" | bc)
}

charge_start() {
	sleep 3
	curl --request POST -H 'Authorization: Bearer '$bearer_token'' $tesla_api_url$tesla_vehicle_id/command/charge_start
}

charge_stop() {
	sleep 3
	curl --request POST -H 'Authorization: Bearer '$bearer_token'' $tesla_api_url$tesla_vehicle_id/command/charge_stop
}
