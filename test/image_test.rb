# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'

require_relative '../cms'

class CMSImageTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
    FileUtils.mkdir_p(image_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
    FileUtils.rm_rf(image_path)
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

  def test_view_image_upload_form
    get '/images/upload', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<form action="/images/upload"'
    assert_includes last_response.body, '<input type="file"'
  end

  def test_view_image_upload_form_without_signin
    get '/images/upload'

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_uploading_image
    # rubocop:disable Style/ExpandPathArguments
    file_path = File.expand_path('../fish.jpg', __FILE__)
    # rubocop:enable Style/ExpandPathArguments

    image = Rack::Test::UploadedFile.new(file_path, 'image/jpeg')

    post '/images/upload', { image: image }, admin_session

    assert_equal 302, last_response.status
    assert_equal 'fish.jpg successfully uploaded.', session[:message]

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'fish.jpg successfully uploaded.'
    assert File.file?(File.join(image_path, 'fish.jpg')), 'fish.jpg has not been created.'
  end

  def test_uploading_image_without_signin
    # rubocop:disable Style/ExpandPathArguments
    file_path = File.expand_path('../fish.jpg', __FILE__)
    # rubocop:enable Style/ExpandPathArguments

    image = Rack::Test::UploadedFile.new(file_path, 'image/jpg')

    post '/images/upload', { image: image }

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_viewing_an_image
    # rubocop:disable Style/ExpandPathArguments
    source_path = File.expand_path('../fish.jpg', __FILE__)
    # rubocop:enable Style/ExpandPathArguments
    FileUtils.cp(source_path, File.join(image_path, 'fish.jpg'))

    get '/images/fish.jpg'

    assert_equal 200, last_response.status
    assert_equal 'image/jpg', last_response['Content-Type']
  end

  def test_viewing_a_nonexistant_image
    get '/images/fish.jpg'

    assert_equal 302, last_response.status
    assert_equal 'fish.jpg does not exist.', session[:message]
  end

  def test_viewing_an_invalid_image
    File.write(File.join(image_path, 'test.test'), 'This is a test.')

    get '/images/test.test'

    assert_equal 302, last_response.status
    assert_equal 'test.test is not a recognized image.', session[:message]
  end

  def test_deleting_an_image
    # rubocop:disable Style/ExpandPathArguments
    FileUtils.cp(File.expand_path('../fish.jpg', __FILE__), File.join(image_path, 'fish.jpg'))
    # rubocop:enable Style/ExpandPathArguments

    post '/images/fish.jpg/delete', {}, admin_session

    assert_equal 302, last_response.status
    assert_equal 'fish.jpg has been deleted.', session[:message]
  end

  def test_deleting_a_nonexistant_image
    post '/images/fish.jpg/delete', {}, admin_session

    assert_equal 302, last_response.status
    assert_equal 'fish.jpg does not exist.', session[:message]
  end
end
