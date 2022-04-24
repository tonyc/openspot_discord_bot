require 'rest-client'
require 'net/http'
require 'discordrb'
require 'awesome_print'

require_relative 'openspot'


if ARGV.length != 1
  puts "Usage: #{$0} <openspot ip address>"
  exit 1
end

ACTIVITY_TYPE_LISTENING = 2 
DISCORD_CLIENT_SECRET = ENV.fetch("DISCORD_CLIENT_SECRET")
DISCORD_BOT_TOKEN = ENV.fetch("DISCORD_BOT_TOKEN")
DISCORD_CLIENT_ID="YOUR_DISCORD_CLIENT_ID"
CHANNEL = "YOUR_DISCORD_CHANNEL_ID"

bot = Discordrb::Bot.new(token: DISCORD_BOT_TOKEN, client_id: DISCORD_CLIENT_ID)
bot.run(true)
bot.update_status("idle", "", nil)

openspot = Openspot.new(ARGV[0], ENV.fetch("OSP_PASS", "openspot"))

openspot.on_call_start do |current_callsign, response_json|
  connected_to = response_json.fetch("connected_to")
  message = "#{current_callsign} on #{connected_to}"

  bot.send_message(CHANNEL, message)
  bot.update_status("online", message, nil, 0, false, ACTIVITY_TYPE_LISTENING)
end

openspot.on_call_idle do |response_json|
  bot.send_message(CHANNEL, "In call => Idle")
  bot.update_status("idle", "", nil)
end


begin
  openspot.authenticate()
  openspot.monitor_status!
rescue Exception => ex
  puts "Caught Exception: #{ex}"
  bot.stop(true)
end

