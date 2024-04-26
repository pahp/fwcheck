#!/usr/bin/env bash
#
# runs a series of checks
#
function do_test() {

	SHOULD_FAIL=$1
	CMD="$2"

	RET=$($SSH_CMD "curl http://server:80/ 2> /dev/null")

	if [[ -n $RET ]] # we got a reply, which means it succeeded!
	then
		if [[ $SHOULD_FAIL == 0 ]]
		then
			echo " YES! :)"
		else
			echo " NO! :("
			exit 1
		fi
	else
		if [[ $SHOULD_FAIL == 0 ]]
		then
			echo " NO! :("
			exit 1
		else
			echo " YES :)"
		fi
	fi
}

DEBUG=true
TEMPFILE=$(mktemp)
SSH_CMD="ssh -o StrictHostKeyChecking=no -i /root/.ssh/fwtest root@client" 

$DEBUG && echo "Tempfile is $TEMPFILE"

if [[ $USER != "root" ]]
then
	echo "Please run sudo ./checker.sh"
	exit 1
fi

echo -n "Test to see if client can reach server:443 (tcp)..."
do_test 0 "curl --insecure -I https://server/ 2> /dev/null"

echo -n "Test to see if client can reach server:80 (tcp)..."
do_test 0 "curl http://server/ 2> /dev/null"

echo -n "Test to see if client can reach server:3306 (tcp) [mysql]"
do_test 0 "/root/fwcheck/talk.sh -H server -p 3306 -q"

