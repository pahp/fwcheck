#!/usr/bin/env bash

# bootstrap fwcheck

echo 'Checking on status of fwcheck install...'
if [[ ! -d ~/fwcheck ]]
then echo '~/fwcheck does not exist -- cloning...'
	cd ~
	git clone https://github.com/pahp/fwcheck.git
	exit $?
else echo 'fwcheck exists!' 
	echo 'Safety check: Is it our git repo?'
	cd ~/fwcheck
	if grep https://github.com/pahp/fwcheck.git .git/config
	then echo 'Seems to be!'
		echo 'Making sure it has not been modified...'
		if git diff | grep diff
		then
			echo 'Repo has been modified! Quitting!'
			exit 1
		else
			echo 'Making sure existing repo is up to date...'
			git pull
			exit $?
		fi
	else echo 'Fatal: fwcheck does not appear to be from https://github.com/pahp/fwcheck.git!'
		exit 1
	fi
fi

