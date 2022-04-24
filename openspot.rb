require 'rest-client'
require 'net/http'
require 'json'
require 'digest'


class Openspot
  JSON_HEADERS = {
    "Content-Type" => "application/json",
    "Accept" => "application/json",
    "Connection" => "keep-alive"
  }

  STATE_IDLE = 0
  STATE_IN_CALL = 1

  def initialize(hostname = "openspot.local", password = "openspot")
    @hostname = hostname
    @password = password
  end

  def authenticate
    puts "Logging in..."
    puts "Logged into openspot at #{@hostname}"

    response = RestClient.get api_url("gettok.cgi")
    json = JSON.parse(response.body)
    token = json.fetch("token")
    digest = digest_password(@password, token)

    response = RestClient.post(api_url("login.cgi"), { token: token, digest: digest }.to_json, JSON_HEADERS)
    json = JSON.parse(response.body)

    hostname = json.fetch("hostname")

    @jwt_token = json.fetch("jwt")
  end

  def on_call_start(&blk)
    @on_call_start = blk
  end

  def on_call_idle(&blk)
    @on_call_idle = blk
  end

  def monitor_status!
    Net::HTTP.start(@hostname, 80) do |http|
      current_callsign = nil

      puts "Waiting for calls..."

      previous_status = nil

      loop do
        json = get_status(http, @jwt_token)

        status = json.fetch("status")

        connected_to = json.fetch("connected_to")
        callinfo = json.fetch("callinfo")

        last_heard_timestamp = nil

        current_callsign = callinfo[0][1] if callinfo.length == 1

        if status == STATE_IDLE
          #puts "status = idle, no callsign"
          current_callsign = nil

          if previous_status == STATE_IN_CALL
            message = "In call => Idle"

            @on_call_idle.call(json)


          elsif previous_status == STATE_IDLE
            puts "Idle"
          end

        elsif status == STATE_IN_CALL
          if previous_status == STATE_IDLE


            puts "Idle => In call"

            if current_callsign
              @on_call_start.call(current_callsign, json)

            else
              message = "#{connected_to}"

              puts "update status: '#{message}'"
            end

          elsif previous_status == STATE_IN_CALL
            message = "In call: "

            if connected_to
              message << connected_to
            end

            if current_callsign
              message << " from: #{current_callsign.inspect}"
            end

            puts message

          elsif previous_status == nil
            puts "Call starting"
          end

        end

        previous_status = status

        puts "*" * 80

        sleep 3.0
      end
    end
  end

  private
  def digest_password(password, token)
    Digest::SHA256.hexdigest("#{token}#{password}")
  end

  def api_url(path)
    "http://#{@hostname}/#{path}"
  end

  def authenticated_json_headers(jwt)
    JSON_HEADERS.merge({
      "Authorization" => "Bearer #{jwt}"
    })
  end

  def get_status(http, token)
    request = Net::HTTP::Get.new("/status.cgi")
    request['Connection'] = "keep-alive"
    request['Accept'] = 'application/json'
    request['Authorization'] = "Bearer #{token}"

    response = http.request(request)

    JSON.parse(response.body.to_s)
  end
end
