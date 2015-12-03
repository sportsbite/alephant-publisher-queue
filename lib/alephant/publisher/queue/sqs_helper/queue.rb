require "aws-sdk"
require "alephant/logger"

module Alephant
  module Publisher
    module Queue
      module SQSHelper
        class Queue
          WAIT_TIME = 5
          VISABILITY_TIMEOUT = 300

          include Logger

          attr_reader :queue, :timeout, :wait_time, :archiver

          def initialize(
            queue,
            archiver  = nil,
            timeout   = VISABILITY_TIMEOUT,
            wait_time = WAIT_TIME
          )
            @queue     = queue
            @archiver  = archiver
            @timeout   = timeout
            @wait_time = wait_time
            log_queue_creation queue.url, archiver, timeout
          end

          def message
            receive.tap { |m| process(m) unless m.nil? }
          end

          private

          def log_queue_creation(queue_url, archiver, timeout)
            logger.info(
              "event"    => "QueueConfigured",
              "queueUrl" => queue_url,
              "archiver" => archiver,
              "timeout"  => timeout,
              "method"   => "#{self.class}#initialize"
            )
          end

          def process(m)
            logger.metric "MessagesReceived"
            logger.info(
              "event"     => "QueueMessageReceived",
              "messageId" => m.id,
              "method"    => "#{self.class}#process"
            )
            archive m
          end

          def archive(m)
            archiver.see(m) unless archiver.nil?
          rescue StandardError => e
            logger.metric "ArchiveFailed"
            logger.error(
              "event"     => "MessageArchiveFailed",
              "class"     => e.class,
              "message"   => e.message,
              "backtrace" => e.backtrace.join.to_s,
              "method"    => "#{self.class}#archive"
            )
          end

          def receive
            queue.receive_message(
              :visibility_timeout => timeout,
              :wait_time_seconds  => wait_time
            )
          end
        end
      end
    end
  end
end
