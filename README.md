temp-throttle
=============

Linux shell script for throttling system CPU frequency based on a desired maximum temperature.
Forked from http://github.com/Sepero/temp-throttle/

Tweaked for my laptop (Dell Precision M4800), with faster check intervals and GPU fan control.

Added files for OpenRC integration: initscript and config files.
````
MAX_TEMP=$(cat /etc/conf.d/maxtemp.conf)
TRIP_GPU_TEMP=$(cat /etc/conf.d/gputemp.conf)
````
