#!/bin/bash
usage() { echo -e "Usage: ${0} [-h] [-g] [-c|-n] [-d] \n -c = cpu support (SIMD)\n -n = arm support (neon)\n -g = gpu support (OPENCL)\n -d = debug build\n -h = this text aka help\n"; exit 2; }

user="miner"
features=""
add_feature() {
	if [ ${#features} -gt 0 ]
	then
		features="${features},${1}"
	else
		features="${1}"
	fi
}
# little wrapper for everything which is executed as $user
ea() { sudo -u "${user}" /bin/bash -c "${1}"; }
# -g = gpu enabled
# -c = cpu enabled
# -n = neon enabled
# -d = debug build
# -h = help
while getopts 'cdghn' c
do
	case $c in
		c) cpu="true"; add_feature "simd"; ;;
		d) debug="true";;
		g) gpu="true"; add_feature "opencl"; ;;
		h) usage;;
		n) neon="true"; add_feature "neon"; ;;
	esac
done

# sanity checks
if [ "${cpu}" != "true" ] && [ "${gpu}" != "true" ] && [ "${neon}" != "true" ]; then usage; fi
if [ "${cpu}" == "true" ] && [ "${neon}" == "true" ]; then echo "only cpu or neon, both can't be used!"; exit 3; fi
id "${user}" > /dev/null 2>&1
if [ $? -ne 0 ]; then echo "${user} is not a user, please add this user according to the setup guide"; exit 4; fi
if [ ! -d "/home/${user}" ]; then echo "/home/${user} isn't existing, please create a proper homedir for ${user}"; exit 5; fi


echo "Installing Rust as ${user}"
ea "curl https://sh.rustup.rs -so /home/${user}/rustup.sh"
ea "chmod +x /home/${user}/rustup.sh"
ea "/home/${user}/rustup.sh -y"
ea "mkdir -p /home/${user}/sources"
if [ ! -d "/home/${user}/sources/scavenger" ]
then
	ea "cd /home/${user}/sources; git clone https://github.com/PoC-Consortium/scavenger.git"
else
	ea "cd /home/${user}/sources/scavenger; git pull"
fi
if [ "${debug}" == "true" ]
then
	ea "PATH=$PATH:/home/${user}/.cargo/bin; cd /home/${user}/sources/scavenger/; cargo build --features=${features}"
else
	ea "PATH=$PATH:/home/${user}/.cargo/bin; cd /home/${user}/sources/scavenger/; cargo build --release --features=${features}"
fi

if [ "$(ps aux |grep '[/]home/miner/scavenger/scavenger')" != "" ]
then
	echo "scavenger is already running from /home/${user}/scavenger/scavenger, we have to stop it first"
	systemctl stop scavenger.service && echo "scavenger stopped"
	start="true"
fi
ea "cp /home/${user}/sources/scavenger/target/release/scavenger /home/${user}/scavenger/scavenger"

if [ "${start}" == "true" ]; then systemctl start scavenger.service && echo "scavenger started"; fi

if [ ! -f "/home/${user}/scavenger/config.yaml" ]
then
	cp "/home/${user}/sources/scavenger/config.yaml" "/home/${user}/scavenger/config.yaml"
	echo "Scavengers configuration file is located at /home/${user}/scavenger/config.yaml please go ahead and edit it!"
else
	echo "There was an Scavenger configuration already, please make sure you compare your settings with new settings from https://github.com/PoC-Consortium/scavenger/blob/master/config.yaml"
fi

echo 'Please make sure you added >console_log_pattern: "{M} {m}{n}"< to your config.yaml, as this will remove useless timestamps (rsyslog adds them anyway!)'
