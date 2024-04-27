#!/usr/bin/env bash


function assert_prereqs() {
	# check prereqs for the firewall checker

	if ! dpkg -l | grep netcat-openbsd &> /dev/null
	then
		echo "Please install the OpenBSD version of netcat using:"
		echo "sudo apt install netcat-openbsd"
		exit 1
	fi
}
