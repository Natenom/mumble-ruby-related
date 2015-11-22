#!/bin/bash

# This scripts automates stuff that needs to be done before the Mumble-Ruby-Pluginbot Virtualbox appliance can be exported.
# https://wiki.natenom.com/w/VirtualBox_Appliance_for_Mumble-Ruby-Pluginbot

set -x

mpc -p 7701 clear
rm ~/src/.first*

sudo apt-get update
sudo apt-get upgrade
sudo apt-get clean

~/src/mumble-ruby-pluginbot/scripts/updater.sh
sudo fstrim -v /
sudo fstrim -v /home
history -c

echo "Export preparations done..."