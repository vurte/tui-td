# frozen_string_literal: true

require "bundler/gem_tasks"
require "rubocop/rake_task"
require "reek/rake/task"
require "bundler/audit/task"

RuboCop::RakeTask.new
Reek::Rake::Task.new
Bundler::Audit::Task.new

task default: %i[rubocop reek bundle:audit]
