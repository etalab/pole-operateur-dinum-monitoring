require 'sinatra'
require 'json'
require 'net/http'
require 'uri'

set :port, ENV['PORT'] || 4567

MONITORED_URLS = [
  'https://api-entreprise.v2.datapass.api.gouv.fr/',
  'https://api-entreprise.v2.datapass.api.gouv.fr/api/frontal',
  'https://back.datapass.api.gouv.fr/api/ping',
  'https://datapass.api.gouv.fr/',
  'https://entreprise.api.gouv.fr/',
  'https://entreprise.api.gouv.fr/api/frontal',
  'https://entreprise.api.gouv.fr/v3/ping',
  'https://quotient-familial.numerique.gouv.fr/'
].freeze

MONITORED_STATUS_CODES = [
  400,
  401,
  403,
  404,
  500,
  502
]


post '/' do
  create
end

def create
  if is_down_event? && is_monitored_url? && is_monitored_status_code?
    notify_mattermost

    content_type :json
    status 200
    { success: true, message: json_message_alert_down }.to_json
  else
    content_type :json
    status 200
    { success: true, message: 'Event ignored' }.to_json
  end
end

def notify_mattermost
  Net::HTTP.start(mattermost_webhook_uri.host, mattermost_webhook_uri.port, use_ssl: true) do |http|
    request = Net::HTTP::Post.new(mattermost_webhook_uri.request_uri, 'Content-Type' => 'application/json')
    request.body = json_message_alert_down
    http.request(request)
  end
end

def json_message_alert_down
  { text: "@all Alert! #{service_name} is down. The following ping failed on Hyperping: #{hyperping_monitor_url}" }.to_json
end

def service_name
  webhook_params['check']['name']
end

def mattermost_webhook_uri
  URI(ENV['MATTERMOST_WEBHOOK_URL'] || 'https://mattermost.incubateur.net/hooks/not_real_hook')
end

def hyperping_monitor_url
  "https://app.hyperping.io/report/#{webhook_params['check']['monitorUuid']}"
end

def is_down_event?
  webhook_params['event'] == 'check.down'
end

def is_monitored_url?
  MONITORED_URLS.include?(webhook_params['check']['url'])
end

def is_monitored_status_code?
  MONITORED_STATUS_CODES.include?(webhook_params['check']['status'])
end

def webhook_params
  request.body.rewind
  JSON.parse(request.body.read)
end

