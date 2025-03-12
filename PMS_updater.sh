#!/bin/sh

LOGGING=1
VERBOSE=1

# Grab Plex Media Server install directory, regardless of disk layout.
QPKG_NAME="PlexMediaServer"
PMSPATH=$(getcfg -f /etc/config/qpkg.conf $QPKG_NAME Install_path)

# Try to find the Preferences.xml in all possible folders to fetch the token for downloads of PlexPass versions.
PREFS="$PMSPATH"/Library/Plex\ Media\ Server/Preferences.xml

if [ ! -f "$PREFS" ]; then
    echo "Preferences.xml not found. This will likely prevent the script from downloading the latest version of Plex. You can still manually download Plex and run PMS_Updater.sh with the -l flag."
    exit 1
fi

PLEXTOKEN="$(sed -n 's/.*PlexOnlineToken="//p' "${PREFS}" | sed 's/\".*//')"
BASEURL="https://plex.tv/api/downloads/5.json"
TOKENURL="$BASEURL?channel=plexpass&X-Plex-Token=$PLEXTOKEN"
DOWNLOADPATH="./"
LOGPATH="./"
LOGFILE="PMS_Updater.log"
# PMSPARENTPATH="/usr/local/share"
#PMSPATTERN="PlexMediaServer-[0-9]*.[0-9]*.[0-9]*.[0-9]*-[0-9,a-f]*-x86_64.qpkg"

# Initialize CURRENTVER to the script max so if reading the current version fails
# for some reason we don't blindly clobber things
CURRENTVER=9999.9999.9999.9999.9999


usage()
{
cat << EOF
usage: $0 options

This script will search the plex.tv download site for a download link
and if it is newer than the currently installed version the script will
download and optionaly install the new version.

OPTIONS:
   -v      Verbose
EOF
}

##  LogMsg()
##  READS:     STDIN (Piped input) $1 (passed in string) $LOGPATH $LOGFILE
##  MODIFIES:  NONE
##
##  Writes log entries to $LOGGINGPATH/$LOGGINGFILE
LogMsg()
{
    if [ "$1" = "-n" ]; then SWITCH="-n"; fi
    while read IN; do
      tdStamp=`date +"%Y-%m-%d %H:%M.%S"`
      if [ $LOGGING = 1 ]; then echo "$tdStamp  $IN" >> $LOGPATH/$LOGFILE; fi
      if [ $VERBOSE = 1 ] || [ "$1" = "-f" ]; then echo $SWITCH $IN; fi
    done
}


##  verNum()
##  READS:    $1 (passed in string)
##  MODIFIES: NONE
##
##  Converts the Plex version string to a mathmatically comparable
##      number by removing non numericals and padding each section with zeros
##      so v0.9.9.10.485 becomes 00000009000900100485
##      NOTE: Plex version numbers appear to have changed from something like
##      v0.9.14.4.1556-a10e3c2
##      to
##      v1.0.0.2261-a17e99e
##      Unfortunately this makes the new 1.X versions appear to be an older
##      version than the 0.9.X versions. This sed hack will append a .0 version
##      to the 1.X version so that it will now behave correctly. The new 1.X will
##      now looks omething like:
##      1.0.0.2261.0-a17e99e
##      And will convert it to the proper long form such as:
##      00010000000022610000
verNum()
{
    echo "$@" | sed -e 's/^.*[^\.]\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)\([^\.]\)/\1.0\2/' | awk -F. '{ printf("%04d%04d%04d%04d%04d", $1,$2,$3,$4,$5)}'
}


##  webFetch()
##  READS:    $1 (URL) $DOWNLOADPATH $VERBOSE $LOGGING
##  MODIFIES: NONE
##
##  invoke wget with configured account info
webFetch()
{
    local QUIET="-s"
    echo $1
    echo $DOWNLOADPATH

    if [ $VERBOSE = 1 ]; then QUIET=""; fi
    echo Downloading $1 | LogMsg
    curl $QUIET -o "$DOWNLOADPATH/`basename $DOWNLOADURL`" "$1" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo Error downloading $1
        exit 1
    else
        echo Download Complete | LogMsg
    fi
}

##  findLatest()
##  READS:    $URLBASIC $URLPLEXPASS $DOWNLOADPATH $PMSPATTERN $VERBOSE $lOGGING
##  MODIFIES: $DOWNLOADURL
##
##  connects to the Plex.tv download site and scrapes for the latest download link
findLatest()
{
    if [ $VERBOSE = 1 ]; then echo Using URL $BASEURL; fi

    echo Searching $BASEURL for the QNAP x86-64 download URL ..... | LogMsg -n
    DOWNLOADURL="$(curl -s $TOKENURL -o- | "$PMSPATH"/Plex\ Script\ Host -c 'import sys, json; myobj = json.load(sys.stdin); print(myobj["nas"]["QNAP"]["releases"][0]["url"]);')"

    if [ "x$DOWNLOADURL" = "x" ]; then {
        # DOWNLOADURL is zero length, i.e. nothing matched PMSPATTERN. Error and exit
        echo Could not find a QNAP x86-64 download link on page $TOKENURL | LogMsg -f
        exit 1
    } else {
        echo Done. | LogMsg -f
    } fi
}


##  applyUpdate()
##  READS:    $PMSPARENTPATH $PMSLIVEFOLDER $PMSBAKFOLDER $LOCALINSTALLFILE $VERBOSE $LOGGING
##  MODIFIES: NONE
##
##  Removes anything in the specified backup location, stops
##    Plex, moves the current to backup, then tries to extract the new zip
##    to the live location.  If there is an error while unpacking the files
##    are deleted and the backup is moved back.  Plex is then started.
##    It could be possible to check status after starting a new plex and
##    rolling back if it does not start, should check that it is running
##    properly before hand to avoid constantly trying to update a broken
##    install
applyUpdate()
{
    echo Stopping Plex Media Server .....| LogMsg -n
    qpkg_service stop $QPKG_NAME
    echo Done. | LogMsg -f

    echo Installing Plex Media Server .....| LogMsg -n
    sh $LOCALINSTALLFILE
    rm $LOCALINSTALLFILE
    echo Done. | LogMsg -f
    
    echo Starting Plex Media Server .....| LogMsg -n
    qpkg_service start $QPKG_NAME
    echo Done. | LogMsg -f
}

while getopts x."l:d:afvrn" OPTION
do
     case $OPTION in
         v) VERBOSE=1 ;;
         ?) usage; exit 1 ;;
     esac
done

export PYTHONHOME="$PMSPATH/Resources/Python"
export PYTHONPATH="$PYTHONHOME/python27.zip"

# Get the current version
CURRENTVER=`export LD_LIBRARY_PATH=$PMSPATH/lib; $PMSPATH/Plex\ Media\ Server --version`

# check if there is an update available
findLatest || exit $?

if [ $(verNum `basename $DOWNLOADURL`) -gt $(verNum $CURRENTVER) ]; then {
  webFetch "$DOWNLOADURL"  || exit $?
  LOCALINSTALLFILE="$DOWNLOADPATH/`basename $DOWNLOADURL`"
} else {
  echo Already running latest version $CURRENTVER | LogMsg
  exit
} fi

echo Installing $LOCALINSTALLFILE ..... | LogMsg -n
applyUpdate
