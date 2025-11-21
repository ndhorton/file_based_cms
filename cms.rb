# frozen_string_literal: true

require 'tilt/erubi'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'securerandom'
require 'redcarpet'
require 'bcrypt'
require 'yaml'

# TODO: Validate that document names contain an extension that the application supports.
# * Maintain allow list of file exetensions permitted in the CMS
# * Check new filename against the allow list
# The only problem is you also have the load_file_content() case statement where new
# extensions need to be accounted for. So you would have to update in two places.

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

def load_file_content(filename)
  filename = File.basename(filename)
  path = File.join(data_path, filename)
  content = File.read(path)
  case File.extname(path)
  when '.txt'
    headers['Content-Type'] = 'text/plain'
    content
  when '.md'
    erb render_markdown(content)
  end
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

def require_signed_in_user
  return if user_signed_in?

  session[:message] = 'You must be signed in to do that.'
  redirect '/'
end

def render_markdown(content)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(content)
end

def user_signed_in?
  !!session[:username]
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  credentials.key?(username) &&
    (BCrypt::Password.new(credentials[username]) == password)
end

def valid_extension?(filename)
  extension = File.extname(filename)
  ['.md', '.txt'].include? extension
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

  if valid_credentials?(username, password)
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

  filename = File.basename(params[:filename].strip)
  if filename.empty?
    session[:message] = 'A name is required.'
    status 422
    erb :new
  elsif !valid_extension?(filename)
    session[:message] = 'Not a valid filename extension.'
    status 422
    @filename = filename
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
