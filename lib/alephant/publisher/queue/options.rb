require "aws-sdk"
require "alephant/logger"

module Alephant
  module Publisher
    module Queue
      class InvalidKeySpecifiedError < StandardError; end

      class Options
        include Alephant::Logger

        attr_reader :queue, :writer

        QUEUE_OPTS = [
          :receive_wait_time,
          :sqs_queue_name,
          :visibility_timeout,
          :aws_account_id,
          :log_archive_message,
          :log_validator,
          :async_store
        ]

        WRITER_OPTS = [
          :lookup_table_name,
          :msg_vary_id_path,
          :renderer_id,
          :s3_bucket_id,
          :s3_object_path,
          :sequence_id_path,
          :sequencer_table_name,
          :view_path
        ]

        def initialize
          @queue  = {}
          @writer = {}
        end

        def add_queue(opts)
          execute @queue, QUEUE_OPTS, opts
        end

        def add_writer(opts)
          execute @writer, WRITER_OPTS, opts
        end

        private

        def execute(instance, type, opts)
          begin
            validate type, opts
            instance.merge! opts
          rescue InvalidKeySpecifiedError => e
            logger.metric "QueueOptionsInvalidKeySpecified"
            logger.error(
              "event"     => "QueueOptionsKeyInvalid",
              "class"     => e.class,
              "message"   => e.message,
              "backtrace" => e.backtrace.join.to_s,
              "method"    => "#{self.class}#validate"
            )
            puts e.message
          end
        end

        def validate(type, opts)
          opts.each do |key, _value|
            unless type.include? key.to_sym
              raise InvalidKeySpecifiedError, "The key '#{key}' is invalid"
            end
          end
        end
      end
    end
  end
end
