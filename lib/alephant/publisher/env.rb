require "aws-sdk"
require "yaml"
require "alephant/logger"

config_file = "config/aws.yaml"

AWS.eager_autoload!

if File.exist? config_file
  config = YAML.load(File.read(config_file))
  AWS.config(config)
end
