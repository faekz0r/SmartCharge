#!/bin/bash


### User configured vars
# Private Tesla token (key)
. private_vars.sh

# Charging window start & end
start_hour=""
end_hour="12"

# How many hours you want to charge for daily (overrides automatic calculation based on limit)
charge_for_hours="1"

# Set maximum €/mWh price (divide by 10 to get kwh/cents) in integer cents to automatically set charge limit to max_charge_limit (expressed in %)
max_price_for_high_limit="130"

# Charging limits % (price low or high)
max_charge_limit="83"
min_charge_limit="50"

# Your charger power in kW (legacy - has been automated)
# charging_power=
# Battery size in kWh
battery_size="73"

# Do not start the charging cycle if battery is the following amount of percentage below limit
no_charge_buffer="2"



# for testing only
# charge_limit=75
# battery_level=20
