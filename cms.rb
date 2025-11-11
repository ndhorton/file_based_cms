# frozen_string_literal: true

require 'tilt/erubi'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'securerandom'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(64)
end

# rubocop:disable Style/ExpandPathArguments
ROOT = File.expand_path('..', __FILE__).freeze
# rubocop:enable Style/ExpandPathArguments

DATA_DIR = "#{ROOT}/data".freeze

get '/' do
  @files = Dir.glob("#{DATA_DIR}/*").map { |path| File.basename(path) }

  erb :index
end

get '/:filename' do
  file_path = "#{DATA_DIR}/#{params[:filename]}"
  if File.file?(file_path)
    headers['Content-Type'] = 'text/plain'
    File.read(file_path)
  else
    session[:error] = "#{params[:filename]} does not exist."
    redirect '/', 303
  end
end
