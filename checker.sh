#!/usr/bin/env bash
#
# runs a series of checks
#

VERSION=0.7
DEBUG=false
RED='\033[0;31m'
GREEN='\033[1;32m'
NC='\033[0m'
SUCCEED=0
FAIL=1
TESTS=0
PASSED=0

function restrictive_firewall_message_exit() {
	echo "Is $TARGET running and accessible?"
	echo "Was any fwcheck code modified in $TARGET?"
	echo "$TARGET's firewall may be too restrictive!"
	echo "Try disabling the firewall on server with 'sudo /root/firewall/extingui.sh', then"
	echo "try running the checker again. If the checker works, your firewall was too restrictive."
	echo "Fix your firewall and try again. If even this doesn't work, contact your instructor."
	exit 1
}


function do_test() {

	# color info from:
	# https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux

	QUIT_ON_FAIL=$1
	SHOULD_FAIL=$2
	SSH_HOST="$3"
	SSH_CMD="$4"
	RETVAL=false

	$DEBUG && echo "QUIT_ON_FAIL: $QUIT_ON_FAIL SHOULD_FAIL: $SHOULD_FAIL SSH_HOST: $SSH_HOST"
	$DEBUG && echo "SSH_CMD: $SSH_CMD"

	OUTPUT=$(ssh $SSH_HOST "$SSH_CMD")
	RET=$?

	$DEBUG && echo "do_test OUTPUT: '$OUTPUT' RET: $RET"

	if [[ $SHOULD_FAIL == 0 ]]
	then
		# we WANT the connection to SUCCEED
		if [[ $RET == 0 ]] # we connected!
		then
			# success means connecting
			echo -e " ${GREEN}It SHOULD work, and it did! SUCCESS :)${NC}"
			RETVAL=true
		else
			echo -e " ${RED}It should work, but it DIDN'T! FAIL :(${NC}"
			$DEBUG && echo "RET = $RET"
			RETVAL=false
		fi
	else 
		# we WANT the connection to FAIL
		if [[ $RET == 0 ]] # we connected, but that's bad
		then
			# success means NOT connecting
			$DEBUG && echo "OUTPUT: '$OUTPUT' RET: $?"
			echo -e " ${RED}It should NOT work, but it DID! FAIL! :(${NC}"
			$DEBUG && echo "RET = $RET"
			RETVAL=false
		elif [[ $RET == 1 ]]
		then
			echo -e " ${GREEN}It should NOT work, and it DIDN'T! SUCCESS! :)${NC}"
#			echo -e " ${RED}It should NOT work, and it DIDN'T, but we were REJECTED! FAIL! :)${NC}"
#			echo "Ensure that your firewall is DROPping unwanted traffic, not REJECTing it."
			$DEBUG && echo "RET = $RET"
			RETVAL=true
		else
			echo -e " ${GREEN}It should NOT work, and it DIDN'T! SUCCESS! :)${NC}"
			$DEBUG && echo "RET = $RET"
			RETVAL=true
		fi
	fi

	if [[ ! $RETVAL && $QUIT_ON_FAIL == 1 ]]
	then
		echo "Quitting."
		exit 1
	fi

	$RETVAL # return status of do_test

}

LOG=$(mktemp)
$DEBUG && echo "Logfile is $LOG"

echo "Starting Firewall Checker v$VERSION..."

# checking to see if current repo is up to date

if git remote update && git status -uno | grep "Your branch is behind"
then
	echo "Updating checker..."
	git pull
	echo 
	echo "Please restart the checker to use the new version."
	exit 0
else
	echo "Checker up to date!"
fi

# do bootstrap
for TARGET in client server
	do 

	echo "Bootstrapping fwcheck for $TARGET..."

	if ! scp -oStrictHostKeyChecking=no fwbootstrap.sh $TARGET:~/ &> $LOG
	then
		echo "Couldn't scp bootstrap to $TARGET."
		restrictive_firewall_message_exit
	else
		echo "Copied bootstrap to $TARGET!"
	fi

	if ! ssh -oStrictHostKeyChecking=no $TARGET "./fwbootstrap.sh" $LOG
	then
		echo "Bootstrapping the checker failed for host $TARGET"
		restrictive_firewall_message_exit
	else
		echo "Bootstrapping for $TARGET complete!"
	fi
done

$DEBUG && echo "Bootstrapping for all nodes complete."

# check prereqs
source helper.sh
assert_prereqs
if git pull
then
	echo "Up to date."
else
	echo "Fail: Issue updating the fwcheck git repo!"
	exit 1
fi

QUIT_ON_FAIL=1

echo
echo Starting tests!
echo

function client_to_server_tcp443() {
	echo -n "Test $TESTS: client -> server:443 (tcp) [https] (OPTIONAL)? "
	do_test $QUIT_ON_FAIL 0 client "timeout 5 curl --insecure -I https://server/ 2> /dev/null"
}

function client_to_server_tcp80() {
	echo -n "Test $TESTS: client -> server:80 (tcp) [http]..."
	do_test $QUIT_ON_FAIL 0 client "timeout 5 curl http://server/ 2> /dev/null"
}

function client_to_server_tcp22() {
	echo -n "Test $TESTS: client -> server:22 (tcp) [ssh]..."
	do_test $QUIT_ON_FAIL 0 client "cd fwcheck && ./talk.sh -H server -p 22"
}

function client_to_server_tcp3306() {
	echo -n "Test $TESTS: client -> server:3306 (tcp) [mysql] "
	do_test $QUIT_ON_FAIL 0 client "cd fwcheck && ./talk.sh -H server -p 3306 2> /dev/null"
}



function source_ping_dest() {
	SOURCE=$1
	DEST=$2
	if [[ -z $SOURCE || -z $DEST ]];
	then
		echo "Fatal: Usage: source_ping_dest SOURCE DEST"
		exit 1
	fi
	echo -n "Test $TESTS: Can $SOURCE ping $DEST..."
	do_test 0 0 $SOURCE "ping -W 1 -c 1 $DEST"
}

function both_src_to_dst_proto_port() {

	# use then when you have to start a listening process
	# success depends on whether the *listener* gets data

	DESIRE=$1
	SOURCE=$2
	DEST=$3
	PROTO=$4
	UPORT=$5

	echo -n "Test $TESTS: $SOURCE -> $DEST on $PROTO port $UPORT... "

	if [[ $PROTO == "UDP" || $PROTO == "udp" ]]
	then
		PROTO="-u"
	else
		PROTO=""
	fi

	# start talkers in background with a sleep delay
	ssh $SOURCE "cd fwcheck && sleep 5 && sudo ./talk.sh -H $DEST -p $UPORT $PROTO" &> /dev/null &

	# start listener
	do_test $QUIT_ON_FAIL $DESIRE $DEST "cd fwcheck && sudo ./listen.sh -p $UPORT $PROTO"

}

function src_to_dst_tcp_port() {

	# use this function when there is already a TCP service running

	DESIRE=$1
	SOURCE=$2
	DEST=$3
	UPORT=$4

	echo -n "Test $TESTS: $SOURCE -> $DEST on TCP port $UPORT... "

	# start talkers in background with a sleep delay
	do_test $QUIT_ON_FAIL $DESIRE $SOURCE "cd fwcheck && sudo ./talk.sh -H $DEST -p $UPORT"

}

function inc_tests() {
	TESTS=$((TESTS + 1))
}

function inc_passed() {
	PASSED=$((PASSED + 1))
}

source_ping_dest client server
source_ping_dest server client
exit

echo "(3.1) Inbound TCP connections to server on standard ports for OpenSSH, Apache, and MySQL:"
inc_tests && client_to_server_tcp22 && inc_passed
inc_tests 
if client_to_server_tcp80 || client_to_server_tcp443
then
	inc_passed
fi
inc_tests && client_to_server_tcp3306 && inc_passed

echo "	Some similar connections that should fail:"
inc_tests && both_src_to_dst_proto_port $FAIL client server tcp 23 && inc_passed
inc_tests && both_src_to_dst_proto_port $FAIL client server tcp 25565 && inc_passed

echo

echo "(3.2) Inbound to server ports 10000-10005 on UDP:"
inc_tests && both_src_to_dst_proto_port $SUCCEED client server "udp" 10000 && inc_passed
inc_tests && both_src_to_dst_proto_port $SUCCEED client server "udp" 10001 && inc_passed
inc_tests && both_src_to_dst_proto_port $SUCCEED client server "udp" 10002 && inc_passed
inc_tests && both_src_to_dst_proto_port $SUCCEED client server "udp" 10003 && inc_passed
inc_tests && both_src_to_dst_proto_port $SUCCEED client server "udp" 10004 && inc_passed
inc_tests && both_src_to_dst_proto_port $SUCCEED client server "udp" 10005 && inc_passed

echo "	Some similar connections that should fail:"
inc_tests && both_src_to_dst_proto_port $FAIL client server "tcp" 10000 && inc_passed
inc_tests && both_src_to_dst_proto_port $FAIL client server "udp" 10006 && inc_passed

echo

echo "(3.3) Inbound ICMP pings & replies..."
inc_tests && source_ping_dest client server && inc_passed

echo

echo "(3.3) Outbund ICMP pings & replies..."
echo "(Technically, the tasks do not require this, so it is optional.)"
source_ping_dest server client

echo

echo "(3.5) Outbound from server to TCP ports 22, 25 and/or 587, 80 and/ or 443:"
inc_tests && src_to_dst_tcp_port $SUCCEED server client 22 && inc_passed

echo "	Port 25 and/or 587 (need only ONE):"
inc_tests
if both_src_to_dst_proto_port $SUCCEED server client tcp 25 || both_src_to_dst_proto_port $SUCCEED server client tcp 587
then
		inc_passed
fi

echo "	Port 80 and/or 443 (need only ONE):"
inc_tests
if both_src_to_dst_proto_port $SUCCEED server client tcp 80 || both_src_to_dst_proto_port $SUCCEED server client tcp
then
	inc_passed
fi

echo "	Some similar connections that should fail:"
inc_tests && both_src_to_dst_proto_port $FAIL server client tcp 23 && inc_passed
inc_tests && both_src_to_dst_proto_port $FAIL server client tcp 25565 && inc_passed


echo

echo "(3.6) Outbound from server to client on UDP ports 10006-10010:"
inc_tests && both_src_to_dst_proto_port $SUCCEED server client udp 10006 && inc_passed
inc_tests && both_src_to_dst_proto_port $SUCCEED server client udp 10007 && inc_passed
inc_tests && both_src_to_dst_proto_port $SUCCEED server client udp 10008 && inc_passed
inc_tests && both_src_to_dst_proto_port $SUCCEED server client udp 10009 && inc_passed
inc_tests && both_src_to_dst_proto_port $SUCCEED server client udp 10010 && inc_passed
inc_tests && both_src_to_dst_proto_port $FAIL server client udp 10000 && inc_passed
inc_tests && both_src_to_dst_proto_port $FAIL server client tcp 10006 && inc_passed

echo
echo "Firewall currently passes $PASSED of the preceeding $TESTS tests."
echo
cat <<TEXT
Here are a number of tests of various ports / protocols / hosts that should be blocked.
If any of these tests fail, then you are allowing traffic that you shouldn't.
(hit ^C to quit early)...
TEXT

for i in $(seq 1000 1005)
do
	inc_tests && both_src_to_dst_proto_port $FAIL server client tcp $i && inc_passed
	inc_tests && both_src_to_dst_proto_port $FAIL server client udp $i && inc_passed
	inc_tests && both_src_to_dst_proto_port $FAIL client server tcp $i && inc_passed
	inc_tests && both_src_to_dst_proto_port $FAIL client server udp $i && inc_passed
done

echo
echo "Firewall passed $PASSED tests out of $TESTS."
echo
cat <<TEXT
Remember that the firewall cannot test spoofing, and also currently cannot tell
whether you are REJECTing or DROPping unwanted traffic.
TEXT
