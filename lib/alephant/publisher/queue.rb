require_relative "env"

require "alephant/publisher/queue/version"
require "alephant/publisher/queue/options"
require "alephant/publisher/queue/sqs_helper/queue"
require "alephant/publisher/queue/sqs_helper/archiver"
require "alephant/logger"
require "alephant/publisher/queue/processor"
require "json"

module Alephant
  module Publisher
    module Queue
      def self.create(opts = {}, processor = nil)
        processor ||= Processor.new(opts.writer)
        Publisher.new(opts, processor)
      end

      class Publisher
        include Logger

        VISIBILITY_TIMEOUT = 60
        RECEIVE_WAIT_TIME  = 15

        attr_reader :queue, :executor, :opts, :processor

        def initialize(opts, processor = nil)
          @opts = opts
          @processor = processor

          @queue = SQSHelper::Queue.new(
            aws_queue,
            archiver,
            opts.queue[:visibility_timeout] || VISIBILITY_TIMEOUT,
            opts.queue[:receive_wait_time]  || RECEIVE_WAIT_TIME,
          )
        end

        def run!
          loop { processor.consume(@queue.message) }
        end

        private

        def archiver
          SQSHelper::Archiver.new(archive_cache, archiver_opts)
        end

        def archiver_opts
          options = {
            :log_archive_message => true,
            :async_store         => true
          }
          options.each do |key, _value|
            options[key] = opts.queue[key] == "true" if opts.queue.has_key? key
          end
        end

        def archive_cache
          Cache.new(
            opts.writer[:s3_bucket_id],
            opts.writer[:s3_object_path]
          )
        end

        def sqs_client
          @sqs_client ||= AWS::SQS.new
        end

        def sqs_queue_options
          (opts.queue[:aws_account_id].nil? ? {} : fallback).tap do |ops|
            logger.info(
              "event"   => "SQSQueueOptionsConfigured",
              "options" => ops,
              "method"  => "#{self.class}#sqs_queue_options"
            )
          end
        end

        def fallback
          {
            :queue_owner_aws_account_id => opts.queue[:aws_account_id]
          }
        end

        def aws_queue
          queue_url = sqs_client.queues.url_for(
            opts.queue[:sqs_queue_name], sqs_queue_options
          )
          sqs_client.queues[queue_url]
        end
      end
    end
  end
end
