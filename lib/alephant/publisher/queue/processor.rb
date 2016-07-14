require "alephant/publisher/queue/writer"

module Alephant
  module Publisher
    module Queue
      class Processor
        attr_reader :opts

        def initialize(opts = nil)
          @opts = opts
        end

        def consume(msg)
          return if msg.nil?
          write(msg)
          msg.delete
        end

        private

        def writer_config
          opts ? opts.writer : {}
        end

        def write(msg)
          Writer.new(writer_config, msg).run!
        end
      end
    end
  end
end
