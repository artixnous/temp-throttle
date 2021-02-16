#!/bin/bash

# Usage: temp_throttle.sh max_temp
# USE CELSIUS TEMPERATURES.
# version 2.21

cat << EOF
Author: Sepero 2016 (sepero 111 @ gmx . com)
URL: http://github.com/Sepero/temp-throttle/

EOF

# Additional Links
# http://seperohacker.blogspot.com/2012/10/linux-keep-your-cpu-cool-with-frequency.html

# Additional Credits
# Wolfgang Ocker <weo AT weo1 DOT de> - Patch for unspecified cpu frequencies.

# License: GNU GPL 2.0

# Generic  function for printing an error and exiting.
err_exit () {
    echo ""
    echo "Error: $@" 1>&2
    exit 128
}

MAX_TEMP=$(cat /etc/conf.d/maxtemp.conf)
TRIP_GPU_TEMP=$(cat /etc/conf.d/gputemp.conf)
[ $MAX_TEMP == 0 ] && MAX_TEMP=85
[ $TRIP_GPU_TEMP == 0 ] && TRIP_GPU_TEMP=65
echo "MAX_TEMP set to $MAX_TEMP"
echo "TRIP_GPU_TEMP set to $TRIP_GPU_TEMP"

### START Initialize Global variables.

# The frequency will increase when low temperature is reached.
LOW_TEMP=$((MAX_TEMP - 2))
MIN_GPU_TEMP=$((TRIP_GPU_TEMP - 5))

CORES=$(nproc) # Get number of CPU cores.
echo -e "Number of CPU cores detected: $CORES\n"
CORES=$((CORES - 1)) # Subtract 1 from $CORES for easier counting later.
CORES=$(seq 0 $CORES)

# Temperatures internally are calculated to the thousandth.
MAX_TEMP=${MAX_TEMP}000
LOW_TEMP=${LOW_TEMP}000
TRIP_GPU_TEMP=${TRIP_GPU_TEMP}000
MIN_GPU_TEMP=${MIN_GPU_TEMP}000

FREQ_FILE="/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies"
FREQ_MIN="/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq"
FREQ_MAX="/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq"

# Store available cpu frequencies in a space separated string FREQ_LIST.
if [ -f $FREQ_FILE ]; then
    # If $FREQ_FILE exists, get frequencies from it.
    FREQ_LIST=$(cat $FREQ_FILE | xargs -n1 | sort -g -r | xargs) || err_exit "Could not read available cpu frequencies from file $FREQ_FILE"
elif [ -f $FREQ_MIN -a -f $FREQ_MAX ]; then
    # Else if $FREQ_MIN and $FREQ_MAX exist, generate a list of frequencies between them.
    FREQ_LIST=$(seq $(cat $FREQ_MAX) -100000 $(cat $FREQ_MIN)) || err_exit "Could not compute available cpu frequencies"
else
    err_exit "Could not determine available cpu frequencies"
fi

FREQ_LIST_LEN=$(echo $FREQ_LIST | wc -w)

# CURRENT_FREQ will save the index of the currently used frequency in FREQ_LIST.
CURRENT_FREQ=2

# This is a list of possible locations to read the current CPU temperature.
TEMPERATURE_FILES="
/sys/class/thermal/thermal_zone1/temp
null
"

# Store the first temperature location that exists in the variable TEMP_FILE.
# The location stored in $TEMP_FILE will be used for temperature readings.
for file in $TEMPERATURE_FILES; do
    TEMP_FILE=$file
    [ -f $TEMP_FILE ] && break
done

[ $TEMP_FILE == "null" ] && err_exit "The location for temperature reading was not found."


### END Initialize Global variables.


### START define script functions.

# Set the maximum frequency for all cpu cores.
set_freq () {
    # From the string FREQ_LIST, we choose the item at index CURRENT_FREQ.
    FREQ_TO_SET=$(echo $FREQ_LIST | cut -d " " -f $CURRENT_FREQ)
#    echo $FREQ_TO_SET
    for i in $CORES; do
        echo $FREQ_TO_SET 2> /dev/null > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq
        echo "${FREQ_TO_SET} Hz" >| /tmp/CPU_CURR_FREQ
        # Try to set core frequency by writing to /sys/devices.
        # Else, try to set core frequency using command cpufreq-set.
#        { cpufreq-set -c $i --max $FREQ_TO_SET > /dev/null; } ||
        # Else, return error message.
#        { err_exit "Failed to set frequency CPU core$i. Run script as Root user. Some systems may require to install the package cpufrequtils."; }
    done
}

# Will reduce the frequency of cpus if possible.
throttle () {
    if [ $CURRENT_FREQ -lt $FREQ_LIST_LEN ]; then
        CURRENT_FREQ=$((CURRENT_FREQ + 1))
#        echo -n "throttle "
        set_freq $CURRENT_FREQ
    fi
}

# Will increase the frequency of cpus if possible.
unthrottle () {
    if [ $CURRENT_FREQ -ne 1 ]; then
        CURRENT_FREQ=$((CURRENT_FREQ - 1))
#        echo -n "unthrottle "
        set_freq $CURRENT_FREQ
    fi
}

### END define script functions.

echo "Initialize to max CPU frequency"
unthrottle


# Main loop
while true; do
    TEMP=$(cat /sys/class/thermal/thermal_zone1/temp)
    if   [ $TEMP -gt $MAX_TEMP ]; then # Throttle if too hot.
        throttle
    elif [ $TEMP -le $LOW_TEMP ]; then # Unthrottle if cool.
        unthrottle
    fi
    GPUTEMP=$(cat /sys/devices/virtual/hwmon/hwmon3/temp7_input)
    [[ $GPUTEMP -le $TRIP_GPU_TEMP && $GPU_TEMP -lt $MIN_GPU_TEMP ]] && dell-bios-fan-control 1
    sleep 0.5 # The amount of time between checking temperatures.
done
