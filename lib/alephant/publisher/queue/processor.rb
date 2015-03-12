require 'alephant/publisher/queue/writer'
require 'alephant/publisher/queue/processor/base'

module Alephant
  module Publisher
    module Queue
      class Processor < BaseProcessor
        include Logger

        attr_reader :writer_config

        def initialize(writer_config = {})
          @writer_config = writer_config
        end

        def consume(msg)
          unless msg.nil?
            write msg
            msg.delete
            logger.metric(:name => "PublisherQueueProcessorMessagesDeleted", :unit => "Count", :value => 1)
          end
        end

        private

        def write(msg)
          Writer.new(writer_config, msg).run!
        end
      end
    end
  end
end
