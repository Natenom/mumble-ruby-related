#!/bin/bash


### Kill all running mpd instances (of the user botmaster) ... ###
killall mpd
sleep 2
killall mpd


### Start needed mpd instances for botmaster ###
mpd /home/botmaster/mpd1/mpd.conf
#mpd /home/botmaster/mpd2/mpd.conf
#mpd /home/botmaster/mpd3/mpd.conf


### Kill running mumble-ruby-pluginbots (of the user botmaster) ###
killall ruby
sleep 1
killall ruby

source ~/.rvm/scripts/rvm
rvm use @bots


### Start from here to create cert dirs within this directory. ###
cd /home/botmaster/src/mumble-ruby-pluginbot 


### Start Mumble-Ruby-Bots - MPD instances must already be running. ###
# Bot 1
tmux new-session -d -n bot1 'ruby /home/botmaster/src/mumble-ruby-pluginbot/pluginbot.rb'

# Bot 2
#tmux new-session -d -n bot2 'ruby /home/botmaster/src/mumble-ruby-pluginbot/pluginbot.rb'

# Bot 3
#tmux new-session -d -n bot3 'ruby /home/botmaster/src/mumble-ruby-pluginbot/pluginbot.rb'


### Optional: Clear playlist, add music and play it; three lines for every bot ###
# Bot 1
# Comment out the next tree lines if you don't want to always listen to the radio.
mpc -p 7701 clear
mpc -p 7701 add http://ogg.theradio.cc/
mpc -p 7701 play

# Bot 2
#mpc -p 7702 clear
#mpc -p 7702 add http://streams.radio-gfm.net/rockpop.ogg.m3u
#mpc -p 7702 play

# Bot 3
#mpc -p 7703 clear
#mpc -p 7703 add http://stream.url.tld/musik.ogg
#mpc -p 7703 play
