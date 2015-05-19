#!/usr/bin/env ruby

# Taken from https://github.com/SuperTux88/mumble-bots/blob/master/mumble-music.rb and changed to allow parameters.

# Syntax
# ruby bot.rb mumbleserver_host mumbleserver_port mumbleserver_username mumbleserver_userpassword mumbleserver_targetchannel quality_bitrate mpd_fifopath mpd_path mpd_host mpd_port

require "mumble-ruby"
require 'rubygems'
require 'ruby-mpd'
require 'thread'

class MumbleMPD
    def initialize
        @sv_art
        @sv_alb
        @sv_tit

        @mpd_fifopath = ARGV[6].to_s
        @mpd_host = ARGV[7].to_s
        @mpd_port = ARGV[8].to_s

        @mpd = MPD.new @mpd_host, @mpd_port

        @mumbleserver_host = ARGV[0].to_s
        @mumbleserver_port = ARGV[1].to_s
        @mumbleserver_username = ARGV[2].to_s
        @mumbleserver_userpassword = ARGV[3].to_s
        @mumbleserver_targetchannel = ARGV[4].to_s
        @quality_bitrate = ARGV[5].to_i

        @cli = Mumble::Client.new(@mumbleserver_host, @mumbleserver_port) do |conf|
            conf.username = @mumbleserver_username
            conf.password = @mumbleserver_userpassword
            conf.bitrate = @quality_bitrate
        end
    end

    def start
        @cli.connect
        sleep(1)
        @cli.join_channel(@mumbleserver_targetchannel)
        sleep(1)
        @cli.player.stream_named_pipe(@mpd_fifopath)

        @mpd.connect true

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
