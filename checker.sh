#!/usr/bin/env bash
#
# runs a series of checks
#

RED='\033[0;31m'
RED='\033[1;32m'
NC='\033[0m'
function do_test() {

	QUIT_ON_FAIL=$1
	SHOULD_FAIL=$2
	SSH_HOST="$3"
	SSH_CMD="$4"
	PASSED=false

	#$DEBUG && echo "SHOULD_FAIL: $1 SSH_HOST: $2 SSH_CMD: '$3'"

	OUTPUT=$(ssh $SSH_HOST "$SSH_CMD")
	RET=$?

	if [[ $SHOULD_FAIL == 0 ]]
	then
		# we WANT the connection to SUCCEED
		if [[ -n $OUTPUT ]] # we got a reply, which means we connected!
		then
			# success means connecting
			echo " ${GREEN}YES! SUCCESS :)${NC} (we connected, which is good)"
			PASSED=true
		else
			echo " ${RED}NO! FAIL :(${NC} (we couldn't connect, which is bad)"
			PASSED=false
		fi
	else 
		# we WANT the connection to FAIL
		if [[ -n $OUTPUT ]]
		then
			# success means NOT connecting
			echo " ${RED}YES! FAIL :(${NC}  (we connected, which is bad!)"
			PASSED=false
		else
			echo " ${GREEN}NO! SUCCESS :)${NC} (we couldn't connect, which is good!)"
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

DEBUG=true
SSH_CMD="ssh -o StrictHostKeyChecking=no -i /root/.ssh/fwtest root@client" 
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
	echo -n "TEST 1: Can client can reach server:443 (tcp) [https]? "
	do_test $QUIT_ON_FAIL 0 client "curl --insecure -I https://server/ 2> /dev/null"
}

function client_to_server_tcp80() {
	echo -n "Can client reach server:80 (tcp) [http]..."
	do_test $QUIT_ON_FAIL 0 client "curl http://server/ 2> /dev/null"
}

function client_to_server_tcp22() {
	echo -n "Can client reach server:22 (tcp) [ssh]..."
	do_test $QUIT_ON_FAIL 0 client "cd fwcheck && ./talk.sh -H server -p 22"
}

function client_to_server_tcp3306() {
	echo -n "Can client reach server:3306 (tcp) [mysql] "
	do_test $QUIT_ON_FAIL 0 client "cd fwcheck && ./talk.sh -H server -p 3306 -q 2> /dev/null"
}


function xdc_to_server_tcp3306() {
	echo -n "Can XDC reach server:3306 (tcp) [mysql]? It should be disallowed. "
	do_test $QUIT_ON_FAIL 1 localhost "cd fwcheck && ./talk.sh -H server -p 3306 -q 2> /dev/null"
}

function client_ping_server() {
	echo -n "Can client ping server..."
	do_test $QUIT_ON_FAIL 0 client "ping -c 1 server"
}

function client_ping_flubber() {
	echo -n "Can client ping nonexistent machine 'flubber'..."
	do_test $QUIT_ON_FAIL 1 client "ping -c 1 flubber"
}

function server_ping_client() {
	echo -n "Can server ping client..."
	do_test 0 0 server "ping -c 1 client"
	echo "(Technically, the tasks do not require this, but there is a manual test for it.)"
}

function both_src_to_dst_proto_port() {

	# use then when you have to start a listening process
	# success depends on whether the *listener* gets data

	SOURCE=$1
	DEST=$2
	PROT=$3
	UPORT=$4

	echo -n "Can $SOURCE reach $DEST on $PROT port $UPORT... "

	if [[ $PROT == "UDP" || $PROT == "udp" ]]
	then
		PROT="-u"
	else
		PROT=""
	fi

	# start talkers in background with a sleep delay
	ssh $SOURCE "cd fwcheck && sleep 5 && ./talk -H $DEST -p $UPORT $PROT" &> /dev/null &

	# start listener
	do_test $QUIT_ON_FAIL 0 $DEST "cd fwcheck && ./listen.sh -p $UPORT $PROT"

}

function src_to_dst_tcp_port() {

	# use this function when there is already a TCP service running

	SOURCE=$1
	DEST=$2
	UPORT=$3

	echo -n "Can $SOURCE reach $DEST on TCP port $UPORT... "

	# start talkers in background with a sleep delay
	do_test $QUIT_ON_FAIL 0 $SOURCE "cd fwcheck && ./talk.sh -H $DEST -p $UPORT"

}


echo "(3.1) Inbound TCP connections to server on standard ports for OpenSSH, Apache, and MySQL:"
client_to_server_tcp22
client_to_server_tcp80
client_to_server_tcp443
client_to_server_tcp3306
xdc_to_server_tcp3306

echo

echo "(3.2) Inbound to server ports 10000-10005 on UDP:"
both_src_to_dst_proto_port client server "udp" 10000
both_src_to_dst_proto_port client server "udp" 10001
both_src_to_dst_proto_port client server "udp" 10002
both_src_to_dst_proto_port client server "udp" 10003
both_src_to_dst_proto_port client server "udp" 10004
both_src_to_dst_proto_port client server "udp" 10005

echo

echo "(3.3) Inbound ICMP pings & replies..."
client_ping_server

echo

echo "(3.3) Outbund ICMP pings & replies..."
server_ping_client

echo

echo "(3.5) Outbound from server to TCP ports 22, 25, 80, 443:"
src_to_dst_tcp_port server client 22
src_to_dst_tcp_port server client 25
src_to_dst_tcp_port server client 80
src_to_dst_tcp_port server client 443

echo

echo "(3.6) Outbound from server to client on UDP ports 10006-10010:"
both_src_to_dst_proto_port server client udp 10006
both_src_to_dst_proto_port server client udp 10007
both_src_to_dst_proto_port server client udp 10008
both_src_to_dst_proto_port server client udp 10009
both_src_to_dst_proto_port server client udp 10010

echo

echo "Some tests that should not work..."
client_ping_flubber
both_src_to_dst_proto_port client server tcp 81
