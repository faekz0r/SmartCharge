#!/bin/bash

initialize_lock() {
    if ! mkdir /tmp/SmartCharge.lock 2>/dev/null; then
        echo "SmartCharge is already running. Exiting" >&2
        exit 1
    fi
    trap 'rm -rf /tmp/SmartCharge.lock' EXIT
}

load_variables() {
    source user_vars.sh
    source system_vars.sh
    source functions.sh
}

update_last_run_timestamp() {
    echo "$(LC_ALL="et_EE.UTF-8" date "+%T %A %d/%m")" > last_ran_date
}

backup_log() {
    cp main.log "logs/main.log.$(date '+%Y-%m-%d_%H-%M-%S')"
}


get_prices () {

	start_hour=$( date '+%H')

	end_epoch_today=$( date -d 'today '"$end_hour"'' +%s)
	end_epoch_tomorrow=$( date -d 'tomorrow '"$end_hour"'' +%s )
	

	if [ "$start_hour" -gt "$end_hour" ]; then
		end_epoch_time=$end_epoch_tomorrow
	elif [ "$start_hour" -lt "$end_hour" ]; then
		end_epoch_time=$end_epoch_today
	else
		end_epoch_time=$end_epoch_tomorrow
	fi

	start_epoch_time=$( date +%s )
	

	start_year=$(TZ=GMT date -d @"$start_epoch_time" +%Y)
	start_month=$(TZ=GMT date -d @"$start_epoch_time" +%m)
	start_day=$(TZ=GMT date -d @"$start_epoch_time" +%d)
	start_hour_gmt=$(TZ=GMT date -d @"$start_epoch_time" +%H)
	
	end_year=$(TZ=GMT date -d @"$end_epoch_time" +%Y)
	end_month=$(TZ=GMT date -d @"$end_epoch_time" +%m)
	end_day=$(TZ=GMT date -d @"$end_epoch_time" +%d)
	end_hour_gmt=$(TZ=GMT date -d @"$end_epoch_time" +%H)
	
	prices=$($elering_api_curl$start_year-$start_month-$start_day"T"$start_hour_gmt"%3A00%3A00.000Z&end="$end_year-$end_month-$end_day"T"$end_hour_gmt"%3A00%3A00.000Z" | jq -r '.data.ee | map([(.timestamp|tostring), (.price|tostring)] | join(", ")) | join("\n")')

	echo "$prices" > 'prices.csv'
}

# Function to make Tesla API calls
tesla_api_call() {
    local method=$1
    local endpoint=$2
    local data=$3

    local headers="Authorization: Bearer $bearer_token"
    local url="$tesla_api_url$tesla_vehicle_id/$endpoint"

    if [ "$method" == "POST" ]; then
        curl --request POST -H "$headers" --data "$data" "$url"
    elif [ "$method" == "GET" ]; then
        curl --request GET -H "$headers" "$url"
    else
        echo "Unsupported method: $method"
        return 1
    fi
}


refresh_bearer_token () {
	bearer_token=$(printf '{
	    "grant_type": "refresh_token",
	    "client_id": "ownerapi",
	    "refresh_token": "'$refresh_token'"
	}'| http --follow --timeout 10 POST 'https://auth.tesla.com/oauth2/v3/token' Accept:'application/json' Content-Type:'application/json' -p b | jq -r .access_token)
}

sort_prices () {
sort -k2 -g -t, prices.csv > sorted_prices.csv

# fetch cheapest hour price only for max_price_for_high_limit
cheapest_hour_price=$(head -n1 sorted_prices.csv | cut -d ',' -f2)
}

keep_charging_hours_only () {
< sorted_prices.csv head -n "$charge_for_hours" > cheap_sorted_prices.csv
# sort by time
sort -k1 -n -t, cheap_sorted_prices.csv > resorted_prices.csv
}

now_epoch() { date +%s; }
next_hour_epoch() { date -d "$(date -d "next hour" '+%H:00:00')" '+%s'; }
sleep_till_next_hour() { sleep $(( 3600 - $(date +%s) % 3600 )); }


wake_tesla () {
    until tesla_api_call "POST" "wake_up" "" | jq .response.state | grep -q "online";
    do
        sleep 5;
        tesla_api_call "POST" "wake_up" ""
        sleep 10;
    done
    echo "Tesla awoken @ $(date)"
}


check_charge_state () {
    sleep 10

    battery_state_json=

    while [[ -z $battery_state_json ]] || [[ $(echo "$battery_state_json" | jq .response.charge_state) = 'null' ]];
    do
        battery_state_json=$(tesla_api_call "GET" "vehicle_data" "")
        sleep 10
    done

    charge_state=$(echo "$battery_state_json" | jq .response.charge_state)
    battery_level=$(echo "$charge_state" | jq .battery_level)
    charge_limit=$(echo "$charge_state" | jq .charge_limit_soc)
    charging_amps_max=$(echo "$charge_state" | jq .charge_current_request_max)

    if [ "$charging_amps_max" -gt "13" ]
    then
        charging_power=$(echo "$charging_amps_max * 3 * 230 / 1000" | bc)

        # set charging amps to max
        sleep 3
        local data="{\"charging_amps\" : \"$charging_amps_max\"}"
        while [[ "$(tesla_api_call "POST" "command/set_charging_amps" "$data" -o /dev/null -s -w "%{http_code}")" != "200" ]];
        do
            sleep 3;
        done

    else
        charging_power=$(echo "$charging_amps_max * 230 / 1000" | bc)
    fi
}


set_charge_limit_to_max() {
    wake_tesla
    sleep 5

    local data="{\"percent\" : \"$max_charge_limit\"}"

    while [[ "$(tesla_api_call "POST" "command/set_charge_limit" "$data" -o /dev/null -s -w "%{http_code}")" != "200" ]];
    do
        sleep 5;
    done;

    sleep 5
    charge_stop
}


set_charge_limit_to_min() {
    wake_tesla
    sleep 5

    local data="{\"percent\" : \"$min_charge_limit\"}"

    while [[ "$(tesla_api_call "POST" "command/set_charge_limit" "$data" -o /dev/null -s -w "%{http_code}")" != "200" ]];
    do
        sleep 5;
    done;

    sleep 5
    charge_stop
}



time_to_charge() {
	wake_tesla
	check_charge_state
	
	# change locale to en_US to process dotted floating point input numbers correctly
	export LC_NUMERIC="en_US.UTF-8"
	# change cheapest_hour_price to integer
	printf -v cheapest_hour_price_int %.0f "$cheapest_hour_price"

	# if cheapest hour is cheap, set charge limit to max else set charge limit to min
	if [ "$cheapest_hour_price_int" -lt "$max_price_for_high_limit" ]; then # && [ "$charge_limit" -lt "$max_charge_limit" ]; then
		set_charge_limit_to_max
		check_charge_state
	elif [ "$cheapest_hour_price_int" -gt "$max_price_for_high_limit" ]; then
		set_charge_limit_to_min
                check_charge_state
	fi

	one_hour_percentage=$(echo "scale = 2; $charging_power * 100 / $battery_size" | bc)
	seconds_to_limit=$(echo "scale = 2; ($charge_limit - $battery_level) / $one_hour_percentage * 3600" | bc | sed '/\./ s/\.\{0,1\}0\{1,\}$//' )
	if [ "$seconds_to_limit" -lt 0 ]; then
		charge_for_hours=0
	else
		charge_for_hours=$(echo "a=$seconds_to_limit; b=3600; if ( a%b ) a/b+1 else a/b" | bc)
	fi
}

charge_start() {
    sleep 3
    while [[ "$(tesla_api_call "POST" "command/charge_start" "" -o /dev/null -s -w "%{http_code}")" != "200" ]];
    do
        sleep 5;
    done;
    echo "Started charging at: "$(date);
}


charge_stop() {
    sleep 3
    tesla_api_call "POST" "command/charge_stop" ""
}


decide_charge_time() {
    if [[ -n "$charge_for_hours" ]] && [ "$charge_for_hours" -gt 0 ]; then
        seconds_to_limit=$(echo "$charge_for_hours * 3600" | bc)
        set_charge_limit_to_max
    else
        time_to_charge
    fi
}

check_battery_level() {
    if [ $((battery_level + no_charge_buffer)) -ge "$charge_limit" ]; then
        echo "No need to charge, since charge limit is at: $charge_limit%"
        echo "and battery level is at: $battery_level%"
        exit
    fi
}

charge_cycle() {
    for i in $(seq 1 "$charge_for_hours"); do
        cheap_hour_start_csv=$(sed -n "$i"{p} resorted_prices.csv)
        cheap_hour_start_stripped=$(echo "$cheap_hour_start_csv" | awk -F "," '{ print $1 }')

        next_cheap_hour_start_csv=$(sed -n $((i + 1)){p} resorted_prices.csv)
        next_cheap_hour_start_stripped=$(echo "$next_cheap_hour_start_csv" | awk -F "," '{ print $1 }')

        sleep_seconds=$((cheap_hour_start_stripped - $(date +%s) ))

        echo "cheap hour start: $(date -d "@$cheap_hour_start_stripped")"
        echo "cycle nr: $i of $charge_for_hours"
        echo "time is: $(date)"

        # Check if we need to sleep till charge_start and start the sleep if needed
        if [ $sleep_seconds -gt 0 ]; then
            sleep $sleep_seconds
        fi

        refresh_bearer_token
        wake_tesla
        charge_start

        # Sleep till next hour to start the cycle again
        sleep_till_next_hour

        # Check if any hours left to charge
        if [ -z "$next_cheap_hour_start_stripped" ]; then
            charge_stop
            echo "Done charging"
            exit 0
        fi

        # Check if we need to stop charging till next cheap hour
        seconds_to_next_cheap=$((next_cheap_hour_start_stripped - $(date +%s)))
        if [ $seconds_to_next_cheap -gt 60 ]; then
            charge_stop
        fi
    done
}
