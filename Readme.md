# scavenger-tools
A little toolsuite for stuff all around [scavenger](https://github.com/PoC-Consortium/scavenger).

If you need any help or have suggestions, feel free to open an [issue](https://github.com/COhsrt/scavenger-tools/issues/new).

[Pull Requests](https://github.com/COhsrt/scavenger-tools/compare) are always welcome!

It contains
  -  munin plugins
  -  systemd service config
  -  rsyslog config for logs to RAM
  -  logrotate config
  -  additional scripts

## why and what is it good for?
### munin plugins
These are for proper monitoring of your miner setup. By now it monitors
- roundtime
- accepted deadlines
- overall round speed
- scoops

### systemd service config
Usually you will run your miner from a terminal in an interactive session. This isn't needed and will need extra power. Since Burstcoin is known for his low power consumption you will want to run your scavenger installation headless and controlled by an instance which makes sure the miner will keep running.

### rsyslog config for logs to RAM
As Burstcoin is all about mining with HDDs, every SATA/SAS slot in your computer may be used by any large disk. Some will run the OS of the mining machine on an USB-Stick. Now logging is write intensive and will block some cpu-cycles, which we can use in a better way (saving energy for example). The rsyslogd config file will redirect all output of scavenger to another directory then /var/log. For now we think /tmp is the best place for this, because there are temporary files anyway.

### logrotate config
As we don't want to store years of logfiles, there is a template for keeping the logs 7 days. Usually this is enough time for debugging. Some files (errors of deadline submissions) will be kept longer, to be able to find defective plotfiles

### additional scripts
- restart_if_slow: restarts scavenger if it is slower then X seconds (roundtime)
- findHits.php: counts the "submission not accepted" per plotfile, which will enable you to find and replot files which seem to have issues

## Setup
There are some basic system requirements which need to be setup.
- a user which will run scavenger (and has the rights to read the plotfiles!), we will call it "miner"
- /home/miner/scavenger contains the miner-software and the config.yaml
- /root/sources/scavenger-tools will contain this repository
- a /tmp which will contain our log-directory
- systemd as init-system
- rsyslogd as logging deamon (default on: debian, ubuntu, mint) (please pull-request if you know more distros using rsyslogd)
- munin as monitoring system (can be installed on the same machine)

### Step by Step
#### install using .zip file
Keeping this up to date is a bit of a hassle, but you can [download](https://github.com/COhsrt/scavenger-tools/archive/master.zip) this repository as zip.
Just execute this as root:

```
mkdir -p /root/sources
cd /root/sources
wget https://github.com/COhsrt/scavenger-tools/archive/master.zip
unzip master.zip
```

to update just call the instructions above again, but your changes may be overwritten!

#### install using git
Keeping this up to date is way easier, but your changes may be overwritten.
Just execute this as root:

```
mkdir -p /root/sources
cd /root/sources
git clone https://github.com/COhsrt/scavenger-tools.git
```

to update just type:

```
cd /root/sources/scavenger-tools
git pull
```

your changes won't be overwritten.
#### miner user
Adding the miner user, without password

``adduser miner --disabled-password --gecos "miner user"``

if you ever need to switch to the users context login as root (``sudo -i`` or `su`) and type ``su miner``
To give readrights to the plotfiles mount the drives and type the following

```chmod o+r /path/to/drive/*_*_*```
#### /tmp as ramdisk
Sidenote: in our testruns we had 500MB logfiles in 2 months of operating a 200TB rig. This will make 8 Months for 2GB logs. Go check logrotate config aswell!
Add an entry for the ramdisk(2GB) to /etc/fstab - this is reboot persistent.

````
tmpfs           /tmp    tmpfs   nodev,nosuid,size=2G    0   0
````

To move the current content to the ramdisk and mount the ramdisk execute as root:

``mkdir /root/tmp && mv /tmp/* /root/tmp/ && mount /tmp && mv /root/tmp/* /tmp/ && rm -rf /root/tmp``

this will perform:
- add /root/tmp
- move contents from /tmp to /root/tmp
- mount ramdisk under /tmp
- move contents from /root/tmp to /tmp
- delete /root/tmp

#### systemd service
The service does the following stuff for you:
- restart scavener if it stopped working
- writes all output to syslog
- sets nice (system priority to maximum) to -19
- starts scavenger
  - as user "miner"
  - within "/home/miner/scavenger/"
  - after the network is available

To install the service just type those commands, be sure you meet the requirements mentioned above.

```
ln -s /root/sources/scavenger-tools/systemd-config/scavenger.service /lib/systemd/system/scavenger.service
systemctl daemon-reload
systemctl enable scavenger.service
systemctl start scavenger.service
```
#### rsyslog config
As we don't want all the log output from scavenger in /var/log/syslog we will redirect that into different files. Rsyslog will handle logfile and folder creation itself, so we just need to add a symlink and restart the service.

```
ln -s /root/sources/scavenger-tools/rsyslog-config/scavenger.conf /etc/rsyslog.d/scavenger.conf
systemctl restart rsyslog.service
```

#### logrotate config
To keep the logs little in size, theres some logrotate config, you can install it by executing:

```
ln -s /root/sources/scavenger-tools/logrotate-config/scavenger /etc/logrotate.d/scavenger
```

#### munin plugins
The munin plugin itself is a single file, which gives different output depending on the filename which is executed. That's why we will just symlink them and restart munin-node, additionally munin-node needs some rights to read the logfiles (thats another symlink).

```
# Linking the plugins
ln -s /root/sources/scavenger-tools/munin-plugins/scavenger_ /etc/munin/plugins/scavenger_deadline
ln -s /root/sources/scavenger-tools/munin-plugins/scavenger_ /etc/munin/plugins/scavenger_roundtime
ln -s /root/sources/scavenger-tools/munin-plugins/scavenger_ /etc/munin/plugins/scavenger_scoop
ln -s /root/sources/scavenger-tools/munin-plugins/scavenger_ /etc/munin/plugins/scavenger_speed
ln -s /root/sources/scavenger-tools/munin-plugins/scavenger_ /etc/munin/plugins/scavenger_drivestats
ln -s /root/sources/scavenger-tools/munin-plugins/scavenger_config /etc/munin/plugin-conf.d/scavenger
# Restarting munin-node
systemctl restart munin-node.service
```

### Scripts
#### restart_if_slow
This script will restart scavenger.service if scavenger is unusally slow. This tends to happen on less then 1% of the systems but is a nice workaround for people who can't watch their logfiles 24/7.
Just add to your crontab. You may access it as root using ``crontab -e``.

```
*/4 * * * * /root/sources/scavenger-tools/scripts/restart_if_slow
```

#### build_scavenger.sh
This script will build and install scavenger in /home/miner/scavenger. You'll have to edit the config.yaml manually. Be sure you add ``console_log_pattern: "{M} {m}{n}"`` to the config.
This script will accept the following command switches: 

```
Usage: ./build_scavenger.sh [-h] [-g] [-c|-n] [-d] 
 -c = cpu support (SIMD)
 -n = arm support (neon)
 -g = gpu support (OPENCL)
 -d = debug build
 -h = this text aka help

```
