#!/usr/bin/env bash
#
# runs a series of checks
#

TEMPFILE=$(mktemp)

echo "TEMPFILE is $TEMPFILE"

# localhost port 80 is open
echo "Test 1: localhost port 80 is open."
./listen.sh -s 10 -p 8000 > $TEMPFILE &
./talk.sh -H localhost -p 8000
RET=$?
if (( $RET > 1 )) 
then
	if grep "Got data!" $TEMPFILE
	then
		echo "Test passed!"
	else
		echo "RET ok but not output!"
	fi
else
	echo "Test failed!"
fi
