require 'aws-sdk'
require 'yaml'
require 'alephant/logger'
require 'alephant/logger/json'

json_driver = Alephant::Logger::JSON.new(ENV["APP_LOG_LOCATION"] ||= "app.log")
Alephant::Logger.setup json_driver

config_file = 'config/aws.yaml'

AWS.eager_autoload!

if File.exists? config_file
  config = YAML.load(File.read(config_file))
  AWS.config(config)
end
