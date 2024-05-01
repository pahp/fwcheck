#!/usr/bin/env bash

# bootstrap fwcheck

echo 'Checking on status of fwcheck install...'
if [[ ! -d ~/fwcheck ]]
then echo '~/fwcheck does not exist -- cloning...'
	cd ~
	if ! git clone https://github.com/pahp/fwcheck.git
	then
		echo "Couldn't clone git repository. Is firewall too restrictive?"
		echo "If names cannot resolve, you may be restricting the experiment network."
		exit 1
	else
		echo "Cloned repository!"
	fi
else echo 'fwcheck exists!' 
	echo 'Safety check: Is it our git repo?'
	cd ~/fwcheck
	if grep https://github.com/pahp/fwcheck.git .git/config
	then echo 'Seems to be!'

		# squash annoying git messages
		git config pull.rebase false

		echo 'Making sure it has not been modified...'
		if git diff | grep diff
		then
			echo 'Repo has been modified! Quitting!'
			exit 1
		else
			echo 'Making sure existing repo is up to date...'
			if ! git pull
			then
				echo "Couldn't pull from github...? Is your firewall too restrictive?"
				echo "If names cannot resolve, you may be restricting the experiment network."
				exit 1
			else
				echo "Updated the repository if necessary."
			fi
		fi
	else echo 'Fatal: fwcheck does not appear to be from https://github.com/pahp/fwcheck.git!'
		exit 1
	fi
fi

