#!/usr/bin/env bash

# listen.sh -- listens for a particular type of connection
# returns true if it gets it or false if it doesn't within n seconds

function usage() {

cat<<EOF
listen.sh -- listens on a specific port
listen.sh -p PORT [-u] [-s]
	-p NUM 	the port on which to listen
	-u 		use UDP instead of TCP
	-s SEC	listen for SEC seconds before quitting (default: 10)
	-h 		prints this screen

Returns true if it received data, otherwise returns false.

EOF
}

UDP_OPTION=""
SEC=10
OPTIND=""

while getopts "p:s:uh" OPTION
do
	case $OPTION in
		p)
			PORT=$OPTARG
			echo "Port is $PORT."
			;;

		s)
			SEC=$OPTARG
			echo "Will wait $SEC seconds before quitting with error."
			;;
		u)
			echo "Protocol is UDP."
			UDP_OPTION="-u" # null if not enabled
			;;
		h)
			usage
			exit 0
			;;
		*)
			usage
			exit 1
			;;
	esac
done

if [[ -z $PORT ]]
then
	echo "Fatal: Didn't supply a port on which to listen!"

	usage
	exit 1
fi

if ! dpkg -l | grep netcat-openbsd &> /dev/null
then
	echo "Fatal: fwcheck requires the package netcat-openbsd!"
	exit 1
fi

OUTPUT=$(timeout $SEC nc $UDP_OPTION -l $PORT)
RET=$?

if [[ $RET != 0 ]]
then
	echo "Listener timed out."
fi

if [[ -z $OUTPUT ]]
then
	echo "Got no data!"
	exit 1
else
	echo "Got data!"
	exit 0
fi


