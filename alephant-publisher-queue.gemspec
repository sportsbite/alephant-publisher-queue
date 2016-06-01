lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "alephant/publisher/queue/version"

Gem::Specification.new do |spec|
  spec.name          = "alephant-publisher-queue"
  spec.version       = Alephant::Publisher::Queue::VERSION
  spec.authors       = ["BBC News"]
  spec.email         = ["FutureMediaNewsRubyGems@bbc.co.uk"]
  spec.summary       = "Static publishing to S3 based on SQS messages"
  spec.description   = "Static publishing to S3 based on SQS messages"
  spec.homepage      = "https://github.com/BBC-News/alephant-publisher-queue"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rspec-nc"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "listen", "~> 3.0.8"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-remote"
  spec.add_development_dependency "pry-nav"
  spec.add_development_dependency "rake-rspec"
  spec.add_development_dependency "simplecov"

  spec.add_runtime_dependency "rake"
  spec.add_runtime_dependency "aws-sdk", "~> 1.0"
  spec.add_runtime_dependency "crimp"
  spec.add_runtime_dependency "alephant-support"
  spec.add_runtime_dependency "alephant-sequencer", "~> 3"
  spec.add_runtime_dependency "alephant-cache"
  spec.add_runtime_dependency "alephant-logger", "~> 3.1"
  spec.add_runtime_dependency "alephant-lookup", "~> 2"
  spec.add_runtime_dependency "alephant-renderer"
end
