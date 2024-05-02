# fwcheck
A step-by-step checker of a firewall for the Merge firewall lab

# Do the Lab

First, do the lab by starting the `firewall` lab on Merge. Follow the instructions in the lab manual to create the firewall.

Make sure the firewall is running, by executing the following command on the `server` node:

```
$ sudo /root/firewall/firewall.sh
```

# Install the firewall checker

Here are the steps for installing the firewall checker.

## Install `git`

`git` is not normally installed on XDCs by default. Install it by running:

```
$ sudo apt update && sudo apt install git
```

## Clone the repository

Clone the checker repository by, on your XDC, running:

```
git clone https://github.com/pahp/fwcheck.git
```

# Using the firewall checker

To run the checker, do the following on your XDC:

```
$ cd fwcheck
$ ./checker.sh
```

When you run the checker, it will install / update itself on the experiment nodes and then check the firewall on `server` by creating a number of connections. The script will tell you if you passed or failed each test. However, please note that sometimes "passing" means "the connection could not be made" (e.g., if the firewall blocks something it is supposed to). The checker will tell you how many tests you passed.

# What doesn't the checker check?

There are certain things the checker cannot test, such as:

 1. Whether your script properly blocks spoofed traffic
 2. Whether you are `REJECT`ing or `DROP`ping traffic (for certain tests)

You are responsible for making sure that your firewall handles those conditions.

# Troubleshooting

If you get strange errors when you run the checker, e.g., about name resolution, then there's a good chance your firewall is too restrictive and is blocking domain name lookups from server (e.g., your server can't find `github.com` because DNS is blocked).

The checker will fail if you modify the files in `~/fwcheck` on any node.

# Problems?

Contact [pahp@d.umn.edu](mailto:pahp@d.umn.edu).

The script should run a number of tests, and give you a general score at the end. There are a few things the checker cannot test (e.g., spoofing).
If you are not even able to start the script, or you get lots of messages about names not resolving, it's likely you have overly restricted the eth0 network and blocked name to IP resolution. Try disabling your firewall by running sudo /root/firewall/extingui.sh on server, then (on your XDC) run ./checker.sh (i.e., run the checker without your firewall enabled). Then, enable your firewall with sudo /root/firewall/firewall.sh and then run ./checker.sh.
You should pass a lot of tests without the firewall running, but fail a bunch of tests, too. If your firewall is correct, you should pass all the tests.
Please report your issues! This is brand new software and there will certainly be problems.
