# frozen_string_literal: true

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'

require_relative '../cms'

class VCSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
    init_data_repo
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def admin_session
    { 'rack.session' => { username: 'admin' } }
  end

  def create_document(name, content = '')
    File.open(File.join(data_path, name), 'w') { |file| file.write(content) }
  end

  def session
    last_request.env['rack.session']
  end

  def test_repo_initialized
    assert File.directory?(File.join(data_path, '.git'))

    repo = Rugged::Repository.new(data_path)
    assert_equal 'main', repo.branches.first.name

    first_commit = repo.rev_parse('HEAD')
    assert_equal 'First commit.', first_commit.message
  end

  def test_initial_files_copied
    assert File.file?(File.join(data_path, 'about.md'))
    assert File.file?(File.join(data_path, 'changes.txt'))
    assert File.file?(File.join(data_path, 'history.txt'))
    assert File.file?(File.join(data_path, '.gitignore'))
  end

  def test_initial_files_committed
    repo = Rugged::Repository.new(data_path)
    first_commit = repo.rev_parse('HEAD')
    tree = first_commit.tree
    entries = tree.entries
    committed_filenames = entries.map { |entry| entry[:name] }
    assert_includes committed_filenames, 'about.md'
    assert_includes committed_filenames, 'changes.txt'
    assert_includes committed_filenames, 'history.txt'

    assert_includes repo.rev_parse(entries[0][:oid]).content, '# Ruby is...'
    assert_includes repo.rev_parse(entries[1][:oid]).content, 'The new version control'
    assert_includes repo.rev_parse(entries[2][:oid]).content, '1993 - Yukihiro Matsumoto'
  end

  def test_new_created_file_committed
    post '/create', { filename: 'test.txt' }, admin_session

    repo = Rugged::Repository.new(data_path)
    last_commit = repo.rev_parse('HEAD')
    assert_equal "test.txt was created.\n", last_commit.message

    new_entry = last_commit.tree.entries.find { |entry| entry[:name] == 'test.txt' }
    assert_equal 'test.txt', new_entry[:name]
  end

  def test_duplicate_file_committed
    post '/duplicate', { old_filename: 'about.md', filename: 'test.md' }, admin_session

    repo = Rugged::Repository.new(data_path)
    last_commit = repo.rev_parse('HEAD')
    assert_equal "test.md was created.\n", last_commit.message

    new_entry = last_commit.tree.entries.find { |entry| entry[:name] == 'test.md' }
    assert_equal 'test.md', new_entry[:name]

    content = repo.rev_parse(new_entry[:oid]).content
    assert_includes content, '# Ruby is...'
  end

  def test_edit_change_to_file_committed
    post '/about.md', { content: '# This is a test. #' }, admin_session

    repo = Rugged::Repository.new(data_path)
    last_commit = repo.rev_parse('HEAD')
    assert_equal "about.md has been updated.\n", last_commit.message

    entry = last_commit.tree.entries.find { |entry| entry[:name] == 'about.md' }
    blob = repo.rev_parse(entry[:oid])
    assert_includes blob.content, '# This is a test. #'
  end

  def test_file_deletion_committed
    post '/about.md/delete', {}, admin_session

    repo = Rugged::Repository.new(data_path)
    last_commit = repo.rev_parse('HEAD')
    assert_equal "about.md has been deleted.\n", last_commit.message

    commit_filenames = last_commit.tree.entries.map { |entry| entry[:name] }
    refute_includes commit_filenames, 'about.md'
  end
end
