$:.unshift File.expand_path("../lib", __FILE__)
require "turbot_runner/version"

Gem::Specification.new do |gem|
  gem.name    = "turbot-runner"
  gem.version = TurbotRunner::VERSION

  gem.author      = "OpenCorporates"
  gem.email       = "bots@opencorporates.com"
  gem.homepage    = "http://turbot.opencorporates.com/"
  gem.summary     = "Utilities for running bots with Turbot"
  gem.license     = "MIT"

  # use git to list files in main repo
  gem.files = %x{ git ls-files }.split("\n").select do |d|
    d =~ %r{^(License|README|bin/|data/|ext/|lib/|spec/)}
  end

  gem.required_ruby_version = '>=1.9.2'

  gem.add_dependency "json-schema", '2.2.2'
end
