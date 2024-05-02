#!/usr/bin/env bash

# talk.sh -- talks for a particular type of connection
# returns true if it gets it or false if it doesn't within n seconds

function usage() {

cat<<EOF
talk.sh -- talks on a specific port
talk.sh -H HOST -p PORT [-u] [-s]
	-H HOST	the machine to talk to
	-p NUM 		the port on which to talk
	-u 		use UDP instead of TCP
	-s SEC		talk for SEC seconds before quitting (default: 10)
	-q		do not send a payload (makes some services mad)
	-h 		prints this screen

Returns true if it received data, otherwise returns false.

EOF
}

function output_check() {

	OUTPUT=$1
	echo "Output is: '$OUTPUT'"
	if [[ -z $OUTPUT ]]
	then
		echo "-- we got no data. Seems like we're getting DROPped."
		exit 1
	else
		echo "-- we got data back! We made a connection!"
		exit 0
	fi

}

# 'main' starts here

# check prereqs
source helper.sh
assert_prereqs

UDP_OPTION=""
SEC=10
OPTIND=""
SEND_PAYLOAD="1"

while getopts "p:s:H:uhq" OPTION
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
		q)
			echo "We won't send a payload."
			SEND_PAYLOAD=""
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

if [[ $SEND_PAYLOAD ]]
then

	OUTPUT=$(timeout $SEC nc $UDP_OPTION $HOST $PORT <<< "abcdefghijklmnopqrstuvwxyz")
else
	OUTPUT=$(timeout $SEC nc $UDP_OPTION $HOST $PORT)
fi
RET=$?

echo "Return value $RET (with output '$OUTPUT')"

if [[ $RET == 0 ]]
then
	if [[ $UDP_OPTION == "-u" ]]
	then
		echo "Return value 0 -- UDP connection but no listener?"
		exit 1
	else
		echo "Return value 0 -- TCP closed remotely! Checking for data..."
		output_check $OUTPUT
		echo "Returning RET: $RET" # 1 - REJECT, 124 - timeout (DROP)
	fi
elif [[ $RET == 1 ]]
then
	echo "TCP connection failed -- closed port or REJECT!"
	exit $RET
elif (( $RET > 1 ))
then
	echo "nc was killed by timeout -- did we get any data back?"
	output_check $OUTPUT
	exit $RET
fi


