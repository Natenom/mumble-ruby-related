#!/usr/bin/env ruby
 
require 'mumble-ruby'
require 'rubygems'
require 'ruby-mpd'
require 'thread'
 
class MumbleMPD
	def initialize
		#################################################
		###### Change here to adapt for your server #####
		#################################################
		@controlstring = "."
		@debug = true
		@listen_to_private_message_only = true
		@listen_to_registered_users_only = true
		@stop_on_unregistered_users = true
		@use_comment_for_status_display = false #Whether to use comment to display song info; false = send to channel, true = comment
		@template_if_comment_enabled = "<b>Artist: </b>%s<br />"\
							+ "<b>Title: </b>%s<br />" \
							+ "<b>Album: </b>%s<br /><br />" \
							+ "<b>Write %shelp to me, to get a list of my commands!"
		@template_if_comment_disabled = "<b>Artist: </b>DISABLED<br />"\
							+ "<b>Title: </b>DISABLED<br />" \
							+ "<b>Album: </b>DISABLED<br /><br />" \
							+ "<b>Write %shelp to me, to get a list of my commands!"
		#whitelist = [83,48,110,90] #not yet implemented
		#################################################
		###### End: Settings ######
		#################################################

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
		
		@mpd = MPD.new @mpd_host, @mpd_port

		@set_comment_available = false

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
			if xfade.to_i == 0
				xfade = "Off"
				@cli.text_channel(@cli.current_channel, "Crossfade is now: #{xfade}.")
			else
				@cli.text_channel(@cli.current_channel, "Crossfade time (in seconds) is now: #{xfade}.")
			end
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
				if @use_comment_for_status_display == true && @set_comment_available == true
					begin
						@cli.set_comment(@template_if_comment_enabled % [current.artist, current.title, current.album, @controlstring])
					rescue NoMethodError
						if @debug
							puts "#{$!}"
						end
					end
				else
					if current.artist.nil? && current.title.nil? && current.album.nil?
						@cli.text_channel(@cli.current_channel, "#{current.file}")
					else
						@cli.text_channel(@cli.current_channel, "#{current.artist} - #{current.title} (#{current.album})")
					end
				end
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
		
		#current = @mpd.current_song
		#@artist = current.artist
		#@title = current.title
		#@album = current.album
		#Check whether set_comment is available in underlying mumble-ruby.
		begin
			@cli.set_comment("")
			@set_comment_available = true
		rescue NoMethodError
			if @debug
				puts "#{$!}"
			end
			@set_comment_available = false
		end
		
		#Should not neccessary because "@mpd.on :song do |current|" sets the comment already if playing a song.
		#if @set_comment_available == true
		#	#@cli.set_comment(@template_if_comment_disabled)
		#end
		
		@cli.on_user_state do |msg|
			#msg.actor = session_id of user who did something on someone, if self done, both is the same.
			#msg.session = session_id of the target

			msg_target = @cli.users[msg.session]
			
			if msg_target["user_id"].nil?
				msg_userid = -1
				sender_is_registered = false
			else
				msg_userid = msg_target["user_id"]
				sender_is_registered = true
			end
 			
			if @debug
				print "\n\nDEBUG(on_user_state): Message received.\nFrom: \"#{@cli.users[msg.actor].inspect}\"\nContent: #{msg.inspect}\n"
				puts "0: #{msg_target.inspect}"
				puts "1: #{msg_target["user_id"]}"
				puts "2: #{@cli.current_channel["channel_id"]}"
				puts "3: #{msg_target["channel_id"]}"
			end
							
			if @cli.current_channel["channel_id"] == msg_target["channel_id"]
				if (@stop_on_unregistered_users == true && sender_is_registered == false)
					@mpd.stop
					@cli.text_channel(@cli.current_channel, "Sorry guys, an unregistered users joined our channel. I must stop the music in order to avoid legal problems.")
				end
			end
		end
		
		@cli.on_text_message do |msg|
			if @debug
				print "\n\nDEBUG(on_text_message): Message received.\nFrom: \"#{@cli.users[msg.actor].inspect}\"\nContent: #{msg.inspect}\n"
			end
			
			#Some of the next two information we may need later...
			msg_sender = @cli.users[msg.actor]
			
			#This is hacky because mumble uses -1 for user_id of unregistered users,
			# while mumble-ruby seems to just omit the value for unregistered users.
			# With this hacky thing commands from SuperUser are also being ignored.
			if msg_sender["user_id"].nil?
				msg_userid = -1
				sender_is_registered = false
			else
				msg_userid = msg_sender["user_id"]
				sender_is_registered = true
			end
			
			if @listen_to_registered_users_only == true
				if sender_is_registered == false
					puts "Debug: Not listening because @listen_to_registered_users_only is true and sender is unregistered."
					next
				end
			end	
			
			#Check whether message is a private one or was sent to the channel.
			# Private message looks like this:   <Hashie::Mash actor=54 message="#help" session=[119]>
			# Channel message:                   <Hashie::Mash actor=54 channel_id=[530] message="#help">
			# Channel messages don't have a session, so skip them
			if not msg.session
				if @listen_to_private_message_only == true
					if @debug
						puts "Debug: Not listening because @listen_to_private_message_only is true and message was sent to channel."
					end
					next
				end
			end

			if @controllable == "true"
				if msg.message.start_with?("#{@controlstring}") && msg.message.length > @controlstring.length #Check whether we have a command after the controlstring.
					message = msg.message.split(@controlstring)[1] #Remove @controlstring
					
					if message == 'help'
						cc = @controlstring
						@cli.text_user(msg.actor, "<br /><u><b>I know the following commands:</u></b><br />" \
								+ "<br />" \
								+ "<u>Controls:</u><br />" \
								+ "#{cc}<b>play</b> Start playing.<br />" \
								+ "#{cc}<b>pp</b> Toogle play/pause.<br />" \
								+ "#{cc}<b>next</b> Play next song in the playlist.<br />" \
								+ "#{cc}<b>stop</b> Stop the playlist.<br />" \
								+ "#{cc}<b>seek <i>value</i>|<i>+/-value</i></b> Seek to an absolute position (in secods). Use +value or -value to seek relative to the current position.<br />" \
								+ "<br />" \
								+ "<u>Volume:</u><br />" \
								+ "#{cc}<b>v</b> <i>value</i> - Set volume to <i>value</i>.<br />" \
								+ "#{cc}<b>v+</b> Increase volume by 5%.<br />" \
								+ "#{cc}<b>v-</b> Decrease volume by 5%.<br />" \
								+ "#{cc}<b>v++</b> Increase volume by 10%.<br />" \
								+ "#{cc}<b>v--</b> Decrease volume by 10%.<br />" \
								+ "<br />" \
								+ "<u>Channel control:</u><br />" \
								+ "#{cc}<b>stick</b> Sticks the bot to your current channel.<br />" \
								+ "#{cc}<b>unstick</b> unsticks the bot.<br />" \
								+ "#{cc}<b>follow</b> Let the bot follow you.<br />" \
								+ "#{cc}<b>unfollow</b> The bot stops following you.<br />" \
								+ "<br />" \
								+ "<u>Settings:</u><br />" \
								+ "#{cc}<b>displayinfo</b> Toggle where to show the current playling song; either in the comment or as a text message to the channel.<br />" \
								+ "#{cc}<b>consume</b> Toggle mpd´s consume mode which removes played titles from the playlist if on.<br />" \
								+ "#{cc}<b>repeat</b> Toogle mpd´s repeat mode.<br />" \
								+ "#{cc}<b>random</b> Toogle mpd´s random mode.<br />" \
								+ "#{cc}<b>single</b> Toogle mpd´s single mode.<br />" \
								+ "#{cc}<b>crossfade <i>seconds</i></b> Set crossfade in seconds, set 0 to disable it.<br />" \
								+ "<br />" \
								+ "<u>Playlists:</u><br />" \
								+ "#{cc}<b>playlists</b> Show a list of all playlists.<br />" \
								+ "#{cc}<b>playlist <i>number</i></b> Load the playlist and start it. Use #{cc}playlists to get a list of all playlists.<br />" \
						                + "#{cc}<b>playlist</b>Show all items of the currently loaded playlist + the name of it.<br />" \
								+ "#{cc}<b>clear</b> Clears the current queue.<br />" \
								+ "<br />" \
								+ "<u>Specials:</u><br />" \
								+ "#{cc}<b>gotobed</b> Let the bot mute and deaf himself and pause the playlist.<br />" \
								+ "#{cc}<b>wakeup</b> The opposite of gotobed.<br />" \
								+ "#{cc}<b>ch</b> Let the bot switch into your channel.<br />" \
								+ "#{cc}<b>song</b> Show the currently played song information.<br />If this information is empty, try #{cc}file instead.<br />" \
								+ "#{cc}<b>file</b> Show the filename of the currently played song if #{cc}song does not contain useful information.<br />" \
						                + "#{cc}<b>help</b> Shows this help.<br />" \
								+ "<hr /><span style='color:grey;font-size:10px;'><a href='http://wiki.natenom.com/w/Superbot'>See here for my documentation.</a></span>")
					end
					if message.match(/^seek [+-]?[0-9]{1,3}$/)
						seekto = message.match(/^seek ([+-]?[0-9]{1,3})$/)[1]
						@mpd.seek seekto
						#status = @mpd.status
						#puts status.class
						#puts status.inspect
						#puts status[0]
						#puts status[":time"].inspect
						#@cli.text_user(msg.actor, "Seeked to position #{status["time"][0]}/#{status["time"][1]}.")
					end
					if message.match(/^crossfade [0-9]{1,3}$/)
						secs = message.match(/^crossfade ([0-9]{1,3})$/)[1].to_i
						@mpd.crossfade = secs
					end
					if message == 'ch'
						channeluserisin = msg_sender["channel_id"]

						if @cli.current_channel["channel_id"].to_i == channeluserisin.to_i
							@cli.text_user(msg.actor, "Hey superbrain, I am already in your channel :)")
						else
							@cli.text_channel(@cli.current_channel, "Hey, \"#{@cli.users[msg.actor].name}\" asked me to make some music, going now. Bye :)")
							@cli.join_channel(channeluserisin)
						end
					end
					if message == 'debug'
						@cli.text_user(msg.actor, "<span style='color:red;font-size:30px;'>Stay out of here :)</span>")
					end
					if message == 'next'
						@mpd.next
					end
					if message == 'prev'
						@mpd.previous
					end
					if message == 'gotobed'
						@cli.join_channel(@mumbleserver_targetchannel)
						@mpd.pause = true
						@cli.deafen true
					end
					if message == 'wakeup'
						@mpd.pause = false
						@cli.deafen false
						@cli.mute false
					end
					if message == 'follow'
							if @alreadyfollowing == true
								@cli.text_user(msg.actor, "I am already following someone! But from now on I will follow you, master.")
								@alreadyfollowing = false
								begin
									Thread.kill(@following)
									@alreadyfollowing = false
								rescue TypeError
									if @debug
										puts "#{$!}"
									end
								end
							end
							
							@follow = true
							@alreadyfollowing = true
							@cli.text_user(msg.actor, "I am following your steps, master.")
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
							@cli.text_user(msg.actor, "I am not following anyone.")
						else
							@follow = false
							@alreadyfollowing = false
							begin
								Thread.kill(@following)
							rescue TypeError
								if @debug
									puts "#{$!}"
								end
								@cli.text_user(msg.actor, "#{@controlstring}follow hasn't been executed yet.")
							end
						end
					end
					if message == 'stick'
						if @alreadysticky == true
							@cli.text_user(msg.actor, "I'm already following someone! Resetting...")
							@alreadysticky = false
							begin
								Thread.kill(@sticked)
								@alreadysticky= false
							rescue TypeError
								if @debug
									puts "#{$!}"
								end
							end
						end
						@sticky = true
						@alreadysticky = true
						channeluserisin = @cli.users[msg.actor].channel_id
						@sticked = Thread.new {
							while @sticky == true do
								if @cli.current_channel == channeluserisin
									sleep(1)
								else
									@cli.join_channel(channeluserisin)
								end
							end
						}
					end
					if message == 'test1'
						@cli.text_user(msg.actor, "#{@set_comment_available}")
						@cli.text_user(msg.actor, "#{@use_comment_for_status_display}")
					end
					if message == 'unstick'
						if @sticky == false
							@cli.text_user(msg.actor, "I am not sticked to a channel currently.")
						else
							@sticky = false
							@alreadysticky = false
							begin
								Thread.kill(@sticked)
							rescue TypeError
								if @debug
									puts "#{$!}"
								end
							end
						end
					end
					if message == 'displayinfo'
						begin
							if @use_comment_for_status_display == true
								@use_comment_for_status_display = false
								@cli.text_user(msg.actor, "Output is now \"Channel\"")
								@cli.set_comment(@template_if_comment_disabled % [@controlstring])
							else
								@use_comment_for_status_display = true
								@cli.text_user(msg.actor, "Output is now \"Comment\"")
								@cli.set_comment(@template_if_comment_enabled)
							end
						rescue NoMethodError
							if @debug
								puts "#{$!}"
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
					if message == 'playlist'
						songlist = @mpd.songs
						puts songlist.inspect
						
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
