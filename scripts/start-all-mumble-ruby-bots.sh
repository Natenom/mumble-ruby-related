#!/bin/bash

### Kill running bots... ###
killall ruby
sleep 1
killall ruby

source ~/.rvm/scripts/rvm
rvm use @bots

### Start from here to create cert dirs within this directory. ###
cd /home/botmaster/user_certificates 


### Start Mumble-Ruby-Bots - MPD instances must already be running. ###

# Bot 1
tmux new-session -d -n bot1 'ruby /home/botmaster/scripts/mumble-ruby-mpd-bot.rb mumble.natenom.com 64738 Bot1_Test "" "Sitzecke" 72000 /home/botmaster/mpd1/mpd.fifo localhost 7701'

# Bot 2
#tmux new-session -d -n bot2 'ruby /home/botmaster/scripts/mumble-ruby-mpd-bot.rb mumble.natenom.com 64738 Bot2_Test "" "Sitzecke" 72000 /home/botmaster/mpd2/mpd.fifo localhost 7702'

# Bot 3
#tmux new-session -d -n bot3 'ruby /home/botmaster/scripts/mumble-ruby-mpd-bot.rb mumble.natenom.com 64738 Bot3_Test "" "Sitzecke" 72000 /home/botmaster/mpd3/mpd.fifo localhost 7703'


### Optional: Clear playlist, add music and play it; three lines for every bot ###

# Bot 1
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
