# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'

require_relative '../cms'

class CMSSignInSignOutTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def admin_session
    { 'rack.session' => { username: 'admin' } }
  end

  def create_document(name, content = '')
    File.open(File.join(data_path, name), 'w') do |file|
      file.write(content)
    end
  end

  def session
    last_request.env['rack.session']
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def test_signin_form
    get '/users/signin'

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<input'
    assert_includes last_response.body, '<button type="submit"'
  end

  def test_signin
    post '/users/signin', username: 'admin', password: 'secret'
    assert_equal 302, last_response.status
    assert_equal 'Welcome!', session[:message]
    assert_equal 'admin', session[:username]

    get last_response['Location']
    assert_includes last_response.body, 'Signed in as admin'
  end

  def test_signin_with_bad_credentials
    post '/users/signin', username: 'guest', password: 'shhhh'
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, 'Invalid credentials'
  end

  def test_signout
    get '/', {}, { 'rack.session' => { username: 'admin' } }
    assert_includes last_response.body, 'Signed in as admin'

    post 'users/signout'
    assert_equal 'You have been signed out.', session[:message]

    get last_response['Location']
    assert_nil session[:username]
    assert_includes last_response.body, 'Sign In'
  end
end

class CMSSignUpTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def admin_session
    { 'rack.session' => { username: 'admin' } }
  end

  def create_document(name, content = '')
    File.open(File.join(data_path, name), 'w') do |file|
      file.write(content)
    end
  end

  def session
    last_request.env['rack.session']
  end

  def teardown
    FileUtils.rm_rf(data_path)
    credentials = load_user_credentials
    credentials.select! { |username, _| username.to_s == 'admin' }
    save_user_credentials(credentials)
  end

  def test_signup_form
    get '/users/signup'

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<input'
    assert_includes last_response.body, '<button type="submit"'
  end

  def test_signup
    post '/users/signup', { username: 'test', password: 'thisisatest' }

    assert_equal 302, last_response.status
    assert_equal 'Account created. Please sign in.', session[:message]

    post '/users/signin', username: 'test', password: 'thisisatest'
    assert_equal 302, last_response.status
    assert_equal 'Welcome!', session[:message]
    assert_equal 'test', session[:username]

    get last_response['Location']
    assert_includes last_response.body, 'Signed in as test'
  end

  def test_signup_with_blank_username
    post '/users/signup', { username: '', password: 'thisisatest' }

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Username cannot be blank'
  end

  def test_signup_with_blank_password
    post '/users/signup', { username: 'test', password: '' }

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Password cannot be blank'
  end

  def test_signup_with_existing_username
    post '/users/signup', { username: 'admin', password: 'thisisatest' }

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'A user with that name already exists.'
  end
end
