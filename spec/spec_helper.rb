$LOAD_PATH << File.join(File.dirname(__FILE__), "..", "lib")

require "pry"
require "aws-sdk"
require "simplecov"

SimpleCov.start do
  add_filter "/spec/"
end

require "alephant/publisher/queue"

RSpec.configure do |config|
  config.order = "random"
end
