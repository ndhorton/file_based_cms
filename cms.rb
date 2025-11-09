# frozen_string_literal: false

require 'tilt/erubi'
require 'sinatra'
require 'sinatra/reloader' if development?

# rubocop:disable Style/ExpandPathArguments
ROOT = File.expand_path('..', __FILE__).freeze
# rubocop:enable Style/ExpandPathArguments

DATA_DIR = "#{ROOT}/data".freeze

get '/' do
  @files = Dir.glob("#{DATA_DIR}/*").map do |path|
    File.basename(path)
  end

  erb :index
end

get '/:filename' do
  file_path = "#{DATA_DIR}/#{params[:filename]}"
  headers['Content-Type'] = 'text/plain'
  File.read(file_path)
end
