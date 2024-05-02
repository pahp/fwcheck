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

One way to troubleshoot is to log on to `server` and disable the firewall by executing:

```
$ sudo /root/firewall/extingui.sh
```

... and then rerunning the checker. If the checker works when your firewall is disabled but fails to run when it is enabled, then your firewall is too restrictive in some way.

The checker will fail if you modify the files in `~/fwcheck` on any node.

# Problems?

Contact [pahp@d.umn.edu](mailto:pahp@d.umn.edu).

Please report your issues! This is brand new software and there will certainly be problems.
