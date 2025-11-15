# frozen_string_literal: true

require 'tilt/erubi'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'securerandom'
require 'redcarpet'
require 'yaml'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(64)
end

def data_path
  if ENV['RACK_ENV'] == 'test'
    # rubocop:disable Style/ExpandPathArguments
    File.expand_path('../test/data', __FILE__)
    # rubocop:enable Style/ExpandPathArguments
  else
    # rubocop:disable Style/ExpandPathArguments
    File.expand_path('../data', __FILE__)
    # rubocop:enable Style/ExpandPathArguments
  end
end

def load_file_content(file)
  case File.extname(file)
  when '.txt'
    headers['Content-Type'] = 'text/plain'
    File.read(file)
  when '.md'
    erb render_markdown(file)
  end
end

def user_signed_in?
  !!session[:username]
end

def require_signed_in_user
  return if user_signed_in?

  session[:message] = 'You must be signed in to do that.'
  redirect '/'
end

def render_markdown(file)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(File.read(file))
end

def load_user_credentials
  # rubocop:disable Style/ExpandPathArguments
  credentials_path = if ENV['RACK_ENV'] == 'test'
                       File.expand_path('../test/users.yml', __FILE__)
                     else
                       File.expand_path('../users.yml', __FILE__)
                     end
  # rubocop:enable Style/ExpandPathArguments
  YAML.load_file(credentials_path)
end

# View index of files in the CMS
get '/' do
  pattern = File.join(data_path, '*')
  @files = Dir.glob(pattern).map { |path| File.basename(path) }

  erb :index
end

# View sign in form
get '/users/signin' do
  erb :signin
end

# Sign user in
post '/users/signin' do
  username = params[:username].strip
  password = params[:password]
  credentials = load_user_credentials

  if credentials.key?(username) && credentials[username] == password
    session[:username] = username
    session[:message] = 'Welcome!'
    redirect '/'
  else
    session[:message] = 'Invalid credentials'
    status 422
    @username = username
    erb :signin
  end
end

# Sign user out
post '/users/signout' do
  session.delete(:username)
  session[:message] = 'You have been signed out.'
  redirect '/'
end

# View the new document page
get '/new' do
  require_signed_in_user
  erb :new
end

# Save a new file
post '/create' do
  require_signed_in_user

  filename = params[:filename].strip
  if filename.empty?
    session[:message] = 'A name is required.'
    status 422
    erb :new
  else
    FileUtils.touch(File.join(data_path, filename))
    session[:message] = "#{filename} was created."
    redirect '/'
  end
end

# View file
get '/:filename' do
  file_path = File.join(data_path, params[:filename])

  if File.file?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect '/'
  end
end

# Edit a file
get '/:filename/edit' do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)

  erb :edit
end

# Save changes to a file
post '/:filename' do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect '/'
end

post '/:filename/delete' do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])
  File.delete(file_path)
  session[:message] = "#{params[:filename]} has been deleted."
  redirect '/'
end
