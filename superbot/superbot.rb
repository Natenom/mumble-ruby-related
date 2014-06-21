#!/usr/bin/env ruby
 
require 'mumble-ruby'
require 'rubygems'
require 'ruby-mpd'
require 'thread'
 
class MumbleMPD
	def initialize
		@mumbleserver_host = ARGV[0].to_s
		@mumbleserver_port = ARGV[1].to_i
		@mumbleserver_username = ARGV[2].to_s
		@mumbleserver_userpassword = ARGV[3].to_s
		@mumbleserver_targetchannel = ARGV[4].to_s
		@quality_bitrate = ARGV[5].to_i
		
		@mpd_fifopath = ARGV[6].to_s
		@mpd_host = ARGV[7].to_s
		@mpd_port = ARGV[8].to_i
		@controllable = ARGV[9].to_s
		@certdirectory = ARGV[10].to_s

		@previouschannel = 0
		
		@mpd = MPD.new @mpd_host, @mpd_port

		@cli = Mumble::Client.new(@mumbleserver_host, @mumbleserver_port) do |conf|
			conf.username = @mumbleserver_username
			conf.password = @mumbleserver_userpassword
			conf.bitrate = @quality_bitrate
			conf.ssl_cert_opts[:cert_dir] = File.expand_path(@certdirectory)
		end
	
		@mpd.on :volume do |volume|
			@cli.text_channel(@cli.current_channel, "Volume was set to: #{volume}.")
		end
		
		@mpd.on :random do |random|
			if random
				random = "On"
			else
				random = "Off"
			end
			
			@cli.text_channel(@cli.current_channel, "Random mode is now: #{random}.")
		end
		
		@mpd.on :single do |single|
			if single
				single = "On"
			else
				single = "Off"
			end
			
			@cli.text_channel(@cli.current_channel, "Single mode is now: #{single}.")
		end
		
		@mpd.on :consume do |consume|
			if consume
				consume = "On"
			else
				consume = "Off"
			end

			@cli.text_channel(@cli.current_channel, "Consume mode is now: #{consume}.")
		end
		
		@mpd.on :xfade do |xfade|
			@cli.text_channel(@cli.current_channel, "Crossfade time (in seconds) is now: #{xfade}.")
		end
		
		@mpd.on :repeat do |repeat|
			if repeat
				repeat = "On"
			else
				repeat = "Off"
			end
			@cli.text_channel(@cli.current_channel, "Repeat mode is now: #{repeat}.")
		end
		
		@mpd.on :song do |current|
			if not current.nil? #Would crash if playlist was empty.
				@cli.text_channel(@cli.current_channel, "#{current.artist} - #{current.title} (#{current.album})")
			end
		end
	end
 
	def start
		@cli.connect
		sleep(1)
		@cli.join_channel(@mumbleserver_targetchannel)
		#sleep(1)
		@cli.stream_raw_audio(@mpd_fifopath)
 
		@mpd.connect true #without true bot does not @cli.text_channel messages other than for !status
		
		@controlstring = "#"
		#whitelist = [83,48,110,90]
		
		@cli.on_text_message do |msg|
			if @controllable == "true"
				if msg.message.start_with?("#{@controlstring}")
					message = msg.message.split(@controlstring)[1] #Remove @controlstring
					
					#initialize
					message_is_from_unregistered_user = false
					
					#Some of the next two information we may need later...
					user_who_sent_message = @cli.users[msg.actor]
					
					#This is hacky because mumble uses -1 for user_id of unregistered users,
					# while mumble-ruby seems to just omit the value for unregistered users.
					# With this hacky thing commands from SuperUser are also being ignored.
					if user_who_sent_message["user_id"].to_i == 0
						message_is_from_unregistered_user = true
					end
					
					if message_is_from_unregistered_user == false #do not accept commands from unregistered users.
						if message == 'help'
							cc = @controlstring
							@cli.text_user(msg.actor, "<br /><u><b>I know the following commands:</u></b><br />" \
									+ "<br />" \
									+ "<u>Controls:</u><br />" \
									+ "#{cc}<b>play</b> Start playing.<br />" \
									+ "#{cc}<b>pp</b> Toogle play/pause.<br />" \
									+ "#{cc}<b>next</b> Play next song in the playlist.<br />" \
									+ "#{cc}<b>stop</b> Stop the playlist.<br />" \
									+ "#{cc}<b>seek</b> Seek to a position.<br />" \
									+ "<br />" \
									+ "<u>Volume:</u><br />" \
									+ "#{cc}<b>v</b> <i>value</i> - Set volume to <i>value</i>.<br />" \
									+ "#{cc}<b>v+</b> Increase volume by 5%.<br />" \
									+ "#{cc}<b>v-</b> Decrease volume by 5%.<br />" \
									+ "#{cc}<b>v++</b> Increase volume by 10%.<br />" \
									+ "#{cc}<b>v--</b> Decrease volume by 10%.<br />" \
									+ "<br />" \
									+ "<u>Channel control:</u><br />" \
									+ "#{cc}<b>ch</b> Let the bot switch into your channel.<br />" \
									+ "#{cc}<b>gohome</b> Let the bot switch to his default channel.<br />" \
									+ "#{cc}<b>stick</b> Sticks the bot to your current channel.<br />" \
									+ "#{cc}<b>unstick</b> unsticks the bot.<br />" \
									+ "#{cc}<b>follow</b> Let the bot follow you.<br />" \
									+ "#{cc}<b>unfollow</b> The bot stops following you.<br />" \
									+ "<br />" \
									+ "<u>Settings:</u><br />" \
									+ "#{cc}<b>consume</b> Toggle mpd´s consume mode which removes played titles from the playlist if on.<br />" \
									+ "#{cc}<b>repeat</b> Toogle mpd´s repeat mode.<br />" \
									+ "#{cc}<b>random</b> Toogle mpd´s random mode.<br />" \
									+ "#{cc}<b>single</b> Toogle mpd´s single mode.<br />" \
									+ "<br />" \
									+ "<u>Playlists:</u><br />" \
									+ "#{cc}<b>playlists</b> Show a list of all playlists.<br />" \
									+ "#{cc}<b>playlist <i>number</i></b> Load the playlist and start it. Use #{cc}playlists to get a list of all playlists.<br />" \
									+ "#{cc}<b>clear</b> Clears the current queue.<br />" \
									+ "<br />" \
									+ "<u>Specials:</u><br />" \
									+ "#{cc}<b>gotobed</b> Let the bot mute and deaf himself and pause the playlist.<br />" \
									+ "#{cc}<b>wakeup</b> The opposite of gotobed.<br />" \
									+ "#{cc}<b>song</b> Show the currently played song information.<br />If this information is empty, try #{cc}file instead.<br />" \
									+ "#{cc}<b>file</b> Show the filename of the currently played song if #{cc}song does not contain useful information.<br />" \
									+ "#{cc}<b>help</b> Shows this help.<br />")
						end
						#if message == 'goback'
						#	@cli.join_channel(@previouschannel)
						#end
						if message == 'ch'
							channeluserisin = user_who_sent_message["channel_id"]

							if @cli.current_channel["channel_id"].to_i == channeluserisin.to_i
								@cli.text_user(msg.actor, "Hey superbrain, I am already in your channel :)")
							else
								@cli.text_channel(@cli.current_channel, "Hey, \"#{@cli.users[msg.actor].name}\" asked me to make some music, going now. Bye :)")
								@cli.join_channel(channeluserisin)
								@mpd.pause = false
							end
						end
						if message == 'debug'
							#@cli.text_user(msg.actor, "#{@cli.users}")
							#@cli.text_user(msg.actor, "#{@cli.users.values.find { |x| x.session == msg.session }}")
							#comesfromuser = @cli.users[msg.session]
							#temp = @cli.users[msg.actor]
							#puts temp.inspect
							#puts @cli.users.values.find { |x| x.session == msg.actor }
							#comesfromuser_session= @cli.users.values.find { |x| x.session == msg.session }
							#puts comesfromuser_session.inspect
							#comesfromuser = @cli.users[comesfromuser_session]
							#puts comesfromuser.inspect
							#@cli.text_user(msg.actor, "#{comesfromuser_session}, #{comesfromuser}")
							#channelfrom = comesfromuser.channel_id
							#@cli.join_channel(channelfrom)
							@cli.text_user(msg.actor, "<span style='color:red;font-size:30px;'>Stay out of here :)</span>")
						end
						#if message.match(/^seek [0-9]{1,5}$/)
						#	seekto = message.match(/^seek ([0-9]{1,5})$/)[1]
						#	puts seekto
						#	@mpd.seek(seekto)
						#end
						if message == 'next'
							@mpd.next
						end
						if message == 'prev'
							@mpd.previous
						end
						if message == 'gotobed'
							#@cli.join_channel(@mumbleserver_targetchannel)
							@mpd.pause = true
							@cli.deafen true
						end
						if message == 'wakeup'
							#@cli.join_channel(@mumbleserver_targetchannel)
							@mpd.pause = false
							@cli.deafen false
							@cli.mute false
						end
						if message == 'gohome'
							@cli.join_channel(@mumbleserver_targetchannel)
							@mpd.pause = true
						end
						if message == 'follow'
								if @alreadyfollowing == true
									@cli.text_user(msg.actor, "#{@controlstring}I'm already following someone! Resetting...")
									@alreadyfollowing = false
									begin
										Thread.kill(@following)
										@alreadyfollowing = false
									rescue TypeError
										puts "#{$!}"
										@cli.text_user(msg.actor, "There was an error stopping the thread.")
									end
								end
								@follow = true
								@alreadyfollowing = true
								@cli.text_user(msg.actor, "I'm following your steps, master")
								currentuser = msg.actor
								@following = Thread.new {
								while @follow == true do
									newchannel = @cli.users[currentuser].channel_id
									@cli.join_channel(newchannel)
									sleep(1)
								end
							}
						end
						if message == 'unfollow'
							if @follow == false
								@cli.text_user(msg.actor, "#{@controlstring}follow hasn't been executed yet.")
							else
								@follow = false
								@alreadyfollowing = false
								begin
									Thread.kill(@following)
								rescue TypeError
									puts "#{$!}"
									@cli.text_user(msg.actor, "#{@controlstring}follow hasn't been executed yet.")
								end
							end
						end
						if message == 'stick'
							if @alreadysticky == true
								@cli.text_user(msg.actor, "#{@controlstring}I'm already following someone! Resetting...")
								@alreadysticky = false
								begin
									Thread.kill(@sticked)
									@alreadysticky= false
								rescue TypeError
									puts "#{$!}"
									@cli.text_user(msg.actor, "#{@controlstring}I'm already following someone! Resetting...")
								end
							end
							@sticky = true
							@alreadysticky = true
							channeluserisin = @cli.users[msg.actor].channel_id
							@sticked = Thread.new {
								while @sticky == true do
									@cli.join_channel(channeluserisin)
									sleep(1)
								end
							}
						end
						if message == 'unstick'
							if @sticky == false
								@cli.text_user(msg.actor, "#{@controlstring}unstick hasn't been executed yet.")
							else
								@sticky = false
								@alreadysticky = false
								begin
									Thread.kill(@sticked)
								rescue TypeError
									puts "#{$!}"
									@cli.text_user(msg.actor, "#{@controlstring}unstick hasn't been executed yet.")
								end
							end
						end
						if message.match(/^v [0-9]{1,3}$/)
							volume = message.match(/^v ([0-9]{1,3})$/)[1].to_i
							
							if (volume >=0 ) && (volume <= 100)
								@mpd.volume = volume
							else
								@cli.text_user(msg.actor, "Volume can be within a range of 0 to 100")
							end
								
						end
						if message == 'v-'
							volume = ((@mpd.volume).to_i - 5)
							if volume < 0
								#@cli.text_channel(@cli.current_channel, "Volume is already 0.")
								volume = 0
							end
							
							@mpd.volume = volume
						end
						if message == 'v--'
							volume = ((@mpd.volume).to_i - 10)
							if volume < 0
								#@cli.text_channel(@cli.current_channel, "Volume is already 0.")
								volume = 0
							end
							
							@mpd.volume = volume
						end
						if message == 'v+'
							volume = ((@mpd.volume).to_i + 5)
							if volume > 100
								#@cli.text_channel(@cli.current_channel, "Volume is already 100.")
								volume = 100
							end
							
							@mpd.volume = volume
						end
						if message == 'v++'
							volume = ((@mpd.volume).to_i + 10)
							if volume > 100
								#@cli.text_channel(@cli.current_channel, "Volume is already 100.")
								volume = 100
							end
							
							@mpd.volume = volume
						end
						if message == 'clear'
							@mpd.clear
							@cli.text_user(msg.actor, "The playqueue was cleared.")
						end
						if message == 'kaguBe' || message == '42'
							@cli.text_user(msg.actor, "<a href='http://wiki.natenom.de/sammelsurium/kagube'>All glory to kaguBe!</a>")
						end
						if message == 'random'
							@mpd.random = !@mpd.random?
						end
						if message == 'repeat'
							@mpd.repeat = !@mpd.repeat?
						end
						if message == 'single'
							@mpd.single = !@mpd.single?
						end
						if message == 'consume'
							@mpd.consume = !@mpd.consume?
						end
						if message == 'pp'
							@mpd.pause = !@mpd.paused?
						end
						if message == 'stop'
							@mpd.stop
						end
						if message == 'play'
							@mpd.play
							@cli.deafen false
							@cli.mute false
						end
						if message == 'playlists'
							text_out = ""
							counter = 0
							@mpd.playlists.each do |playlist|
								text_out = text_out + "#{counter} - #{playlist.name}<br/>"
								counter = counter + 1
							end
							
							@cli.text_user(msg.actor, "I know the following playlists:<br />#{text_out}")
						end
						#if message.match(/^playlist [a-z0-9][^\w]$/)
						if message.match(/^playlist [0-9]{1,3}.*$/)
							playlist_id = message.match(/^playlist ([0-9]{1,3})$/)[1].to_i
							
							begin
								playlist = @mpd.playlists[playlist_id]
								@mpd.clear
								playlist.load
								@mpd.play
								@cli.text_user(msg.actor, "The playlist \"#{playlist.name}\" was loaded and starts now, have fun :)")
							rescue
								@cli.text_user(msg.actor, "Sorry, the given playlist id does not exist.")
							end
							
							#if (playlist = @mpd.playlists[playlist_id]) #I am sure there is a better way :)
							#	playlist = @mpd.playlists[playlist_id]
							#	@mpd.clear
							#	playlist.load
							#	@mpd.play
							#	@cli.text_user(msg.actor, "The playlist \"#{playlist.name}\" was loaded and starts now, have fun :)")
							#else
							#	@cli.text_user(msg.actor, "Sorry, the given playlist id does not exist.")
							#end
						
							#If name was given, use this ... do later and distinct between number and name ...
							#playlist_name = message.match(/^playlist (.*)$/)[1]
							#@mpd.playlists.each do |playlist|
							#	if playlist.name == playlist_name
							#		@mpd.clear
							#		playlist.load
							#		@mpd.play
							#	end
							#end
						end
						if message == 'status'
							status = @mpd.status
							@cli.text_user(msg.actor, "Sorry, this is still the raw message I get from mpd...:<br />#{status.inspect}")
						end
						if message.match(/[fF][uU][cC][kK]/)
							@cli.text_user(msg.actor, "Fuck is an English-language word, a profanity which refers to the act of sexual intercourse and is also commonly used to denote disdain or as an intensifier. Its origin is obscure; it is usually considered to be first attested to around 1475, but may be considerably older. In modern usage, the term fuck and its derivatives (such as fucker and fucking) can be used in the position of a noun, a verb, an adjective or an adverb.<br />Source: <a href='http://en.wikipedia.org/wiki/Fuck'>Wikipedia</a>")
						end
						if message == 'file'
							current = @mpd.current_song
							@cli.text_user(msg.actor, "Filename of currently played song:<br />#{current.file}</span>")
						end
						if message == 'song'
							current = @mpd.current_song
							if not current.nil? #Would crash if playlist was empty.
								@cli.text_user(msg.actor, "#{current.artist} - #{current.title} (#{current.album})")
							else
								@cli.text_user(msg.actor, "No song is played currently.")
							end
						end
					end
				#else
					#@cli.text_channel(@cli.current_channel, "Sorry, I don't know this command :)")
				end
			#else
				#@cli.text_channel(@cli.current_channel, "Sorry, I am configured to not execute commands.")
			end
		end
		
		begin
			t = Thread.new do
				$stdin.gets
			end
 
			t.join
		rescue Interrupt => e
		end
	end
end
 
client = MumbleMPD.new
client.start
