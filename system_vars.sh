#!/bin/bash


### Tesla API vars
tesla_api_url='https://owner-api.teslamotors.com/api/1/vehicles/'




# debugging
# set -v -x -e

# since we stop charging at end_hour, we don't need its price
if (( $end_hour > 0 )); then
end_hour=$(( end_hour - 1 ))
else
end_hour=23
fi


# if perl -e 'exit ((localtime)[8])' ; then
	# winter time
	# current_hour_gmt=$( date -d "2 hours ago" "+%H" )
	# start_hour_gmt=$( date -d "$start_hour 2 hours ago" "+%H" )
	# end_hour_gmt=$( date -d "$end_hour_minus_one 2 hours ago" "+%H" )
# else
	# summer time
	# current_hour_gmt=$( date -d "2 hours ago" "+%H" )
	# start_hour_gmt=$( date -d "$start_hour 3 hours ago" "+%H" )
	# end_hour_gmt=$( date -d "$end_hour_minus_one 3 hours ago" "+%H" )
# fi




### Elering API
elering_api_curl='curl -X GET https://dashboard.elering.ee/api/nps/price?start='


### Time vars
# yearToday=$(date -d today '+%Y')
# monthToday=$(date -d today '+%m')
# dayToday=$(date -d today '+%d')
# hourNow=$(date -d today '+%H')

# yearYesterday=$(date -d yesterday '+%Y')
# monthYesterday=$(date -d yesterday '+%m')
# dayYesterday=$(date -d yesterday '+%d')

# yearTomorrow=$(date -d tomorrow '+%Y')
# monthTomorrow=$(date -d tomorrow '+%m')
# dayTomorrow=$(date -d tomorrow '+%d')



