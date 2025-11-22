# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'

require_relative '../cms'

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
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

  def test_index
    create_document('about.md')
    create_document('changes.txt')

    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'about.md'
    assert_includes last_response.body, 'changes.txt'
  end

  def test_viewing_text_document
    create_document('history.txt', 'Ruby 0.95 released')

    get '/history.txt'

    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_includes last_response.body, 'Ruby 0.95 released'
  end

  def test_viewing_markdown_document
    create_document('about.md', '# Ruby is...')

    get '/about.md'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h1>Ruby is...</h1>'
  end

  def test_document_not_found
    get '/notafile.ext'

    assert_equal 302, last_response.status
    assert_equal 'notafile.ext does not exist.', session[:message]
  end

  def test_editing_document
    create_document('changes.txt')

    get '/changes.txt/edit', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<textarea'
    assert_includes last_response.body, '<button type="submit"'
  end

  def test_editing_document_signed_out
    create_document('changes.txt')

    get '/changes.txt/edit'

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_updating_document
    post '/changes.txt', { content: 'new content' }, admin_session

    assert_equal 302, last_response.status
    assert_equal 'changes.txt has been updated.', session[:message]

    get '/changes.txt'

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'new content'
  end

  def test_updating_document_signed_out
    post '/changes.txt', { content: 'new content' }

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def view_new_document_form
    get '/new', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<input'
    assert_includes last_response.body, '<button type="submit"'
  end

  def view_new_document_form_signed_out
    get '/new'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_create_new_document
    post '/create', { filename: 'test.txt' }, admin_session

    assert_equal 302, last_response.status
    assert_equal 'test.txt was created.', session[:message]

    get '/', {}, { 'rack.session' => { message: nil } }

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'test.txt'
  end

  def test_create_new_document_signed_out
    post '/create', filename: 'test.txt'

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_create_new_document_without_filename
    post '/create', { filename: '' }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'A name is required.'
  end

  def test_create_new_document_without_filename_signed_out
    post '/create', filename: ''

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_create_new_document_with_existing_filename
    create_document('test.txt')

    post '/create', { filename: 'test.txt' }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'A file with that name already exists.'
  end

  def test_create_new_document_with_disallowed_extension
    post '/create', { filename: 'test.test' }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Not a valid filename extension.'
  end

  def test_create_new_document_with_disallowed_extension_signed_out
    post '/create', { filename: 'test.test' }

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_deleting_document
    create_document('test.txt')

    post '/test.txt/delete', {}, admin_session

    assert_equal 302, last_response.status
    assert_equal 'test.txt has been deleted.', session[:message]

    get '/', {}, { 'rack.session' => { message: nil } }

    assert_equal 200, last_response.status
    refute_includes last_response.body, 'test.txt'
  end

  def test_deleting_document_signed_out
    create_document('test.txt')

    post '/test.txt/delete'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_viewing_duplicate_form
    create_document('test.txt')

    get '/test.txt/duplicate', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<form action="/duplicate"'
  end

  def test_duplicating_file
    create_document('test.txt')

    post '/duplicate', { old_filename: 'test.txt', filename: 'test_dup.txt' }, admin_session

    assert_equal 302, last_response.status
    assert_equal 'test_dup.txt was created.', session[:message]
  end

  def test_duplicating_file_without_signin
    create_document('test.txt')

    post '/duplicate', { old_filename: 'test.txt', filename: 'test_dup.txt' }

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_duplicating_file_with_no_new_filename
    create_document('test.txt')

    post '/duplicate', { old_filename: 'test.txt', filename: '     ' }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'A name is required.'
  end

  def test_duplicating_file_with_same_filename
    create_document('test.txt')

    post '/duplicate', { old_filename: 'test.txt', filename: 'test.txt' }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'A file with that name already exists.'
  end

  def test_duplicating_file_with_invalid_extension_for_new_filename
    create_document('test.txt')

    post '/duplicate', { old_filename: 'test.txt', filename: 'test.test' }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Not a valid filename extension.'
  end
end
