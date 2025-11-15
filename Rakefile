# frozen_string_literal: true

require 'rake/testtask'

desc 'Run File-based CMS app'
task :cms do
  ruby 'cms.rb'
end

desc 'Run tests'
task :test

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb']
end
