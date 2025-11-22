# frozen_string_literal: true

require 'tilt/erubi'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'securerandom'
require 'redcarpet'
require 'bcrypt'
require 'yaml'

# TODO: Modify the CMS so that each version of a document is preserved as changes are made to it.

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(64)
end

def data_files
  pattern = File.join(data_path, '*')
  all_data_files = Dir.glob(pattern).map { |path| File.basename(path) }
  all_data_files.select { |filename| valid_extension?(filename) }
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

def filename_exists?(filename)
  data_files.include?(File.basename(filename))
end

def image_path
  # rubocop:disable Style/ExpandPathArguments
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/images', __FILE__)
  else
    File.expand_path('../public/images', __FILE__)
  end
  # rubocop:enable Style/ExpandPathArguments
end

def image_files
  files = Dir.glob("#{image_path}/*").map { |file| File.basename(file) }
  files.select { |file| valid_image?(file) }
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

def save_user_credentials(credentials)
  # rubocop:disable Style/ExpandPathArguments
  credentials_path = if ENV['RACK_ENV'] == 'test'
                       File.expand_path('../test/users.yml', __FILE__)
                     else
                       File.expand_path('../users.yml', __FILE__)
                     end
  # rubocop:enable Style/ExpandPathArguments

  File.write(credentials_path, YAML.dump(credentials))
end

def user_exists?(username)
  credentials = load_user_credentials

  credentials.key?(username)
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

def valid_image?(filename)
  ['.jpg'].include?(File.extname(filename.downcase))
end

# View index of files in the CMS
get '/' do
  @files = data_files
  @images = image_files
  erb :index
end

# View sign up form
get '/users/signup' do
  erb :signup
end

# Sign user up
post '/users/signup' do
  username = params[:username].strip
  password = params[:password]

  if username.empty?
    session[:message] = 'Username cannot be blank.'
    status 422
    erb :signup
  elsif password.empty?
    session[:message] = 'Password cannot be blank.'
    status 422
    erb :signup
  elsif user_exists?(username)
    session[:message] = 'A user with that name already exists.'
    status 422
    @username = username
    erb :signup
  else
    credentials = load_user_credentials
    credentials[username] = BCrypt::Password.create(password).to_s
    save_user_credentials(credentials)
    session[:message] = 'Account created. Please sign in.'
    redirect '/'
  end
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
  elsif filename_exists?(filename)
    session[:message] = 'A file with that name already exists.'
    status 422
    @filename = filename
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

# View the form to duplicate a file
get '/:filename/duplicate' do
  require_signed_in_user

  @filename = File.basename(params[:filename])
  @old_filename = File.basename(params[:filename])

  erb :duplicate
end

# Duplicate a file
post '/duplicate' do
  require_signed_in_user

  @filename = File.basename(params[:filename].strip)
  @old_filename = File.basename(params[:old_filename].strip)
  if @filename.empty?
    session[:message] = 'A name is required.'
    status 422
    erb :duplicate
  elsif filename_exists?(@filename)
    session[:message] = 'A file with that name already exists.'
    status 422
    erb :duplicate
  elsif !valid_extension?(@filename)
    session[:message] = 'Not a valid filename extension.'
    status 422
    erb :duplicate
  else
    # copy old file to new named file
    FileUtils.cp(File.join(data_path, @old_filename), File.join(data_path, @filename))
    session[:message] = "#{@filename} was created."
    redirect '/'
  end
end

# View file
get '/:filename' do
  filename = File.basename(params[:filename])
  redirect "/images/#{filename}" if valid_image?(filename) && File.file?(File.join(image_path, filename))
  file_path = File.join(data_path, filename)

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

  @filename = File.basename(params[:filename])
  file_path = File.join(data_path, @filename)
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

# Delete a file
post '/:filename/delete' do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])
  File.delete(file_path)
  session[:message] = "#{params[:filename]} has been deleted."
  redirect '/'
end

# View upload form for images
get '/images/upload' do
  require_signed_in_user
  erb :upload
end

# Save an uploaded image
post '/images/upload' do
  require_signed_in_user

  image = params[:image]
  FileUtils.cp(image['tempfile'].path, File.join(image_path, image['filename']))
  session[:message] = "#{image['filename']} successfully uploaded."
  redirect '/'
end

# View an image
get '/images/:filename' do
  filename = File.basename(params[:filename])
  file_path = File.join(image_path, filename)
  if !File.file?(file_path)
    session[:message] = "#{filename} does not exist."
    redirect '/'
  elsif !valid_image?(filename)
    session[:message] = "#{filename} is not a recognized image."
    redirect '/'
  end

  image_type = File.extname(filename)[1..]
  headers['Content-Type'] = "image/#{image_type}"
  send_file file_path
end

# Delete an image
post '/images/:filename/delete' do
  require_signed_in_user

  filename = File.basename(params[:filename])
  file_path = File.join(image_path, filename)
  if File.file?(file_path)
    FileUtils.rm(file_path)
    session[:message] = "#{filename} has been deleted."
  else
    session[:message] = "#{filename} does not exist."
  end
  redirect '/'
end
