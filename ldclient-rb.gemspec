# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ldclient-rb/version'

Gem::Specification.new do |spec|
  spec.name          = "ldclient-rb"
  spec.version       = LaunchDarkly::VERSION
  spec.authors       = ["LaunchDarkly"]
  spec.email         = ["team@launchdarkly.com"]
  spec.summary       = %q{LaunchDarkly SDK for Ruby}
  spec.description   = %q{Official LaunchDarkly SDK for Ruby}
  spec.homepage      = "https://rubygems.org/gems/ldclient-rb"
  spec.license       = "Apache 2.0"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_runtime_dependency "json", "~> 1.8"
  spec.add_runtime_dependency "faraday", "~> 0.9"
  spec.add_runtime_dependency "faraday-http-cache", "~> 0.4"
  spec.add_runtime_dependency "thread_safe", "~> 0.3"
  spec.add_runtime_dependency "net-http-persistent", "~> 2.9"
  #spec.add_runtime_dependency "celluloid-eventsource", "~> 0.3"
  spec.add_runtime_dependency "em-eventsource", "~> 0.2"
  spec.add_runtime_dependency "concurrent-ruby", "~> 0.9"
  spec.add_runtime_dependency "hashdiff", "~> 0.2"
end
