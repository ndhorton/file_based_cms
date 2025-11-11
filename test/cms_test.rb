# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'

require_relative '../cms'

ALPHABET = [*('a'..'z')].freeze

def random_nonexistent_document(filenames)
  result = []

  loop do
    8.times { result << ALPHABET.sample }
    result << '.'
    3.times { result << ALPHABET.sample }
    break unless filenames.include? result.join

    result = []
  end

  result.join
end

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    filenames = Dir.glob("#{DATA_DIR}/*").map { |path| File.basename(path) }

    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    filenames.each do |filename|
      assert_includes(last_response.body, filename, "The text '#{filename}' not contained in response body.")
    end
  end

  def test_text_file_view
    filenames = Dir.glob("#{DATA_DIR}/*").map { |path| File.basename(path) }

    get "/#{filenames.first}"

    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_equal File.read("#{DATA_DIR}/#{filenames.first}"), last_response.body
  end

  def test_request_for_nonexistent_document
    filenames = Dir.glob("#{DATA_DIR}/*").map { |path| File.basename(path) }
    nonexistent_document = random_nonexistent_document(filenames)

    get "/#{nonexistent_document}"

    assert_equal 303, last_response.status
    assert last_response['Location'], "'Location' header does not exist."
    refute_empty last_response['Location']
    assert_empty last_response.body

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, "#{nonexistent_document} does not exist."
    filenames.each do |filename|
      assert_includes last_response.body, filename
    end

    get '/'
    refute_includes last_response.body, "#{nonexistent_document} does not exist."
  end
end
