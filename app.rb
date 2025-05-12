require 'sinatra'

set :port, ENV['PORT'] || 4567

get '/' do
  'Hello World'
end

