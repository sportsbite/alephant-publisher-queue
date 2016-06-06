require "faraday"
require "aws-sdk"
require "alephant/publisher/queue/writer"

module Alephant
  module Publisher
    module Queue
      class RevalidateProcessor
        attr_reader :writer_config, :url_generator

        def initialize(writer_config = {}, url_generator)
          @writer_config = writer_config
          @url_generator = url_generator
        end

        def consume(message)
          return if message.nil?

          http_response = get(message)
          http_message  = build_http_message(message, http_response)

          writer(http_message).run!

          message.delete
        end

        private

        def writer(message)
          Writer.new(writer_config, message)
        end

        def build_http_message(message, http_response)
          # I feel dirty...
          # FIXME: refactor `Writer` so it's not so tightly coupled to a AWS::SQS::ReceivedMessage object
          http_message = message.dup
          http_message.instance_variable_set(:@body, http_response)
          http_message
        end

        def get(message)
          url = url_generator.generate(message)
          res = Faraday.get(url)
          res.body
        end
      end
    end
  end
end
