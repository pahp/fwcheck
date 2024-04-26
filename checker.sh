#!/usr/bin/env bash
#
# runs a series of checks
#

TEMPFILE=$(mktemp)
SSH_CMD="ssh -o StrictHostKeyChecking=no -i /root/.ssh/fwtest root@client" 

echo "TEMPFILE is $TEMPFILE"

if [[ $USER != "root" ]]
then
	echo "Please run sudo ./checker.sh"
	exit 1
fi

echo "Test to see if client can reach server:443..."

FOO=$($SSH_CMD "curl --insecure -I https://server/")

echo -n "server:443 (tcp) is "
if [[ -n $FOO ]]
then
	echo "accessible from client! :)"
else
	echo "not accessible from client! :("
	exit 1
fi


