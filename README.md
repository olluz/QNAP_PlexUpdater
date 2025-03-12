I've copied this (with pride) from https://github.com/mstinaff/PMS_Updater and adjusted for QNAP devices.

Installation:
- place the script in a dir on the NAS
- set the permission (chmod a+x)
- create a cron entry to execute it every night (or however often you wish), like so:
- 45 3 * * * cd /path/to/script/dir/ && ./PMS_Updater.sh

- I'm cd'ing first into the directory so that the log file will be stored in the same dir

The script might need some cleaning up, but it works pretty solid so far. 
No more manual updates!
