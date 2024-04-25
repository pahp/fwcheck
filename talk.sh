#!/usr/bin/env bash

# talk.sh -- talks for a particular type of connection
# returns true if it gets it or false if it doesn't within n seconds

function usage() {

cat<<EOF
talk.sh -- talks on a specific port
talk.sh -H HOST -p PORT [-u] [-s]
	-H HOST	the machine to talk to
	-p NUM 		the port on which to talk
	-u 			use UDP instead of TCP
	-s SEC		talk for SEC seconds before quitting (default: 10)
	-h 			prints this screen

Returns true if it received data, otherwise returns false.

EOF
}

UDP_OPTION=""
SEC=10
OPTIND=""

while getopts "p:s:H:uh" OPTION
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
		H)
			HOST=$OPTARG
			echo "We'll try to reach host '$HOST'."
			;;
		*)
			usage
			exit 1
			;;
	esac
done

if [[ -z $PORT ]]
then
	echo "Fatal: Didn't supply a port on which to talk!"

	usage
	exit 1
fi

if ! dpkg -l | grep netcat-openbsd &> /dev/null
then
	echo "Fatal: fwcheck requires the package netcat-openbsd!"
	exit 1
fi

OUTPUT=$(timeout $SEC nc $UDP_OPTION $HOST $PORT <<< "abcdefghjijklmnopqrstuvwxyz")
RET=$?

echo "Return value $RET (with output '$OUTPUT')"

if [[ $RET == 0 && $UDP_OPTION == "-u" ]]
then
	echo "Return value 0 -- UDP connection but no listener?"
	exit 1
elif [[ $RET == 1 ]]
then
	echo "Could not make a TCP connection."
	exit 1
elif (( $RET > 1 ))
then
	echo "nc was killed by timeout (usually this means data was sent)."
	exit 0
fi

