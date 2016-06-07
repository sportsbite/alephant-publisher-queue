require_relative "env"

require "alephant/publisher/queue/version"
require "alephant/publisher/queue/options"
require "alephant/publisher/queue/publisher"
require "alephant/publisher/queue/sqs_helper/queue"
require "alephant/publisher/queue/sqs_helper/archiver"
require "alephant/publisher/queue/processor"
require "alephant/publisher/queue/revalidate_processor"
require "alephant/logger"
require "alephant/cache"
require "json"

module Alephant
  module Publisher
    module Queue
      def self.create(opts, processor = nil)
        processor ||= Processor.new(opts)
        Publisher.new(opts, processor)
      end
    end
  end
end
