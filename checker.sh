#!/usr/bin/env bash
#
# runs a series of checks
#

DEBUG=false
RED='\033[0;31m'
GREEN='\033[1;32m'
NC='\033[0m'
SUCCEED=0
FAIL=1

function do_test() {

	# color info from:
	# https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux

	QUIT_ON_FAIL=$1
	SHOULD_FAIL=$2
	SSH_HOST="$3"
	SSH_CMD="$4"
	PASSED=false

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
			PASSED=true
		else
			echo -e " ${RED}It should work, but it DIDN'T! FAIL :(${NC}"
			PASSED=false
		fi
	else 
		# we WANT the connection to FAIL
		if [[ $RET == 0 ]] # we connected, but that's bad
		then
			# success means NOT connecting
			echo "OUTPUT: '$OUTPUT' RET: $?"
			echo -e " ${RED}It should NOT work, but it DID! FAIL! :(${NC}"
			PASSED=false
		else
			echo -e " ${GREEN}It should NOT work, and it DIDN'T! SUCCESS! :)${NC}"
			PASSED=true
		fi
	fi

	if [[ ! $PASSED && $QUIT_ON_FAIL == 1 ]]
	then
		echo "Quitting."
		exit 1
	fi

}

LOG=$(mktemp)
$DEBUG && echo "Logfile is $LOG"

# do bootstrap
for TARGET in client server
	do 

	$DEBUG && echo "Bootstrapping fwcheck for $TARGET..."

	if ! scp fwbootstrap.sh $TARGET:~/ &> $LOG
	then
		echo "Couldn't scp bootstrap to $TARGET."
		exit 1
	else
		$DEBUG && echo "Copied bootstrap to $TARGET!"
	fi

	if ! ssh $TARGET "./fwbootstrap.sh" &> $LOG
	then
		echo "Bootstrapping the checker failed for host $TARGET"
		exit 1
	else
		$DEBUG && echo "Bootstrapping for $TARGET complete!"
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

#if [[ $USER != "root" ]]
#then
#	echo "Please run sudo ./checker.sh"
#	exit 1
#fi


echo
echo Starting tests!
echo

function client_to_server_tcp443() {
	echo -n "TEST 1: Can client reach server:443 (tcp) [https]? "
	do_test $QUIT_ON_FAIL 0 client "timeout 5 curl --insecure -I https://server/ 2> /dev/null"
}

function client_to_server_tcp80() {
	echo -n "Can client reach server:80 (tcp) [http]..."
	do_test $QUIT_ON_FAIL 0 client "timeout 5 curl http://server/ 2> /dev/null"
}

function client_to_server_tcp22() {
	echo -n "Can client reach server:22 (tcp) [ssh]..."
	do_test $QUIT_ON_FAIL 0 client "cd fwcheck && ./talk.sh -H server -p 22"
}

function client_to_server_tcp3306() {
	echo -n "Can client reach server:3306 (tcp) [mysql] "
	do_test $QUIT_ON_FAIL 0 client "cd fwcheck && ./talk.sh -H server -p 3306 -q 2> /dev/null"
}


function client_ping_server() {
	echo -n "Can client ping server..."
	do_test $QUIT_ON_FAIL 0 client "ping -W 5 -c 1 server"
}

function server_ping_client() {
	echo -n "Can server ping client..."
	do_test 0 0 server "ping -W -c 1 client"
	echo "(Technically, the tasks do not require this, but there is a manual test for it.)"
}

function both_src_to_dst_proto_port() {

	# use then when you have to start a listening process
	# success depends on whether the *listener* gets data

	DESIRE=$1
	SOURCE=$2
	DEST=$3
	PROTO=$4
	UPORT=$5

	$DEBUG && echo -n "Can $SOURCE reach $DEST on $PROTO port $UPORT... "

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

	echo -n "Can $SOURCE reach $DEST on TCP port $UPORT... "

	# start talkers in background with a sleep delay
	do_test $QUIT_ON_FAIL $DESIRE $SOURCE "cd fwcheck && sudo ./talk.sh -H $DEST -p $UPORT"

}

both_src_to_dst_proto_port $SUCCEED client server "udp" 10000
exit 

echo "(3.1) Inbound TCP connections to server on standard ports for OpenSSH, Apache, and MySQL:"
client_to_server_tcp22
client_to_server_tcp80
client_to_server_tcp443
client_to_server_tcp3306

echo

echo "(3.2) Inbound to server ports 10000-10005 on UDP:"
both_src_to_dst_proto_port $SUCCEED client server "udp" 10000
both_src_to_dst_proto_port $SUCCEED client server "udp" 10001
both_src_to_dst_proto_port $SUCCEED client server "udp" 10002
both_src_to_dst_proto_port $SUCCEED client server "udp" 10003
both_src_to_dst_proto_port $SUCCEED client server "udp" 10004
both_src_to_dst_proto_port $SUCCEED client server "udp" 10005
both_src_to_dst_proto_port $SUCCEED client server "tcp" 10000
both_src_to_dst_proto_port $FAIL client server "udp" 10006

echo

echo "(3.3) Inbound ICMP pings & replies..."
client_ping_server

echo

echo "(3.3) Outbund ICMP pings & replies..."
server_ping_client

echo

echo "(3.5) Outbound from server to TCP ports 22, 25, 80, 443:"
src_to_dst_tcp_port $SUCCEED server client 22
src_to_dst_tcp_port $SUCCEED server client 25
src_to_dst_tcp_port $SUCCEED server client 80
src_to_dst_tcp_port $SUCCEED server client 443

echo

echo "(3.6) Outbound from server to client on UDP ports 10006-10010:"
both_src_to_dst_proto_port $SUCCEED server client udp 10006
both_src_to_dst_proto_port $SUCCEED server client udp 10007
both_src_to_dst_proto_port $SUCCEED server client udp 10008
both_src_to_dst_proto_port $SUCCEED server client udp 10009
both_src_to_dst_proto_port $SUCCEED server client udp 10010
both_src_to_dst_proto_port $FAIL server client udp 10000
both_src_to_dst_proto_port $FAIL server client tcp 10006

echo

echo "Some tests that should not work..."
both_src_to_dst_proto_port $FAIL client server tcp 1024 
both_src_to_dst_proto_port $FAIL client server tcp 60000
both_src_to_dst_proto_port $FAIL client server udp 53
both_src_to_dst_proto_port $FAIL client server udp 1234
both_src_to_dst_proto_port $FAIL server client udp 1234
both_src_to_dst_proto_port $FAIL server client tcp 1234
both_src_to_dst_proto_port $FAIL server client tcp 23
