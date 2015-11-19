#!/bin/bash
#
# v0.1 (C) 2012 Andrey A. Porodko (Andrey.Porodko@gmail.com)
# v0.2 (C) 2015 Ben Matheja (ben.matheja@zweitag.de)
#
#  Check and report Arkeia backup results 
#
#  $1 - Name of savepack to check status of.

# Nagios status codes
NAGIOS_OK=0
NAGIOS_WARNING=1
NAGIOS_ERROR=2
NAGIOS_UNKNOWN=3
#
# Savepack we are looking for
SAVEPACK=$1
#
LOG_FILE=""
#
# Arkeia status codes
ERROR_CODE=E0*
INFO_CODE=I0*
WARN_CODE=W0*
#
# Arkeia job status files mask
JOBS_PATH=/opt/arkeia/server/report/jobs
# Calculate Datetime of 3 weeks Ago
EPOCH_3W=1814400
NOW=$(date +%s)
DELTA_3W=`expr $NOW - $EPOCH_3W`
COMPARE=$(date -d @$DELTA_3W)
echo $COMPARE
#####################
#Find all .lst files in $JOBS_PATH which are newer than 1 month ago
#TODO: calculate Datetime from 
FILES=`find $JOBS_PATH -name "*.lst" -type f -newermt "20151101" -printf '%T@\t%f\t%Tb %Td %TH:%TM\n'| sort -k1n | cut -f 2- | awk '{print $1}'`
cd $JOBS_PATH
set -- junk $FILES
shift
for file; do
    if [ "$file" != "$JOBS_PATH/bkpmaster.lst" ]; then
	while read LINE; do
	    case "$LINE" in
		*\"$SAVEPACK\"*)
		LOG_FILE=$file
		break
		;;
	    *)
		;;
	    esac
	done < $file
	if [ "$LOG_FILE" != "" ]; then
	    break
	fi
    fi
done

if [ "$LOG_FILE" == "" ]; then
    echo "There are no backup results for $SAVEPACK available."
    exit $NAGIOS_UNKNOWN
fi

while IFS=' ' read -ra LINE; do
    n=1
    msg=""
    for i in "${LINE[@]}"; do
	if [ $n -gt 5 ]; then
	    msg="$msg $i"
	elif [ $n -eq 4 ]; then  # get status code
	    status=$i
	fi
    let n=n+1
    done
    case "$status" in
	$ERROR_CODE)		# When there is an error we pick it up and exit immediately
	    excode=$NAGIOS_ERROR
	    exmsg="There is an error in backup $SAVEPACK. Code: $status. $msg."
	    echo $exmsg
	    exit $excode
	    ;;
	$WARN_CODE)		# When there is a warning we pick it up and exit immediately
	    excode=$NAGIOS_WARNING
	    exmsg="There is a warning in backup $SAVEPACK. Code: $status. $msg."
	    echo $exmsg
	    exit $excode
	    ;;
	$INFO_CODE)		# Status is good so far...
	    excode=$NAGIOS_OK
	    ;;
	*)			# in the rest of cases we think it's UNKNOWN state
	    excode=$NAGIOS_UNKNOWN
	    echo "Current status $status"
	    ;;
    esac
done < $LOG_FILE

if [ $excode -eq $NAGIOS_UNKNOWN ]; then
    exmsg="The status of backup $SAVEPACK is unknown."
elif [ $excode -eq $NAGIOS_OK ]; then
    exmsg="Backup $SAVEPACK completed. Status is OK. Backups found which are newer than 1 month"
fi

echo $exmsg
exit $excode

