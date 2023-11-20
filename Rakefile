# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "syntax_tree/rake_tasks"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

configure = ->(task) do
  task.source_files =
    FileList[%w[Gemfile Rakefile *.gemspec lib/**/*.rb test/**/*.rb]]
end

SyntaxTree::Rake::CheckTask.new(&configure)
SyntaxTree::Rake::WriteTask.new(&configure)

task default: :test
