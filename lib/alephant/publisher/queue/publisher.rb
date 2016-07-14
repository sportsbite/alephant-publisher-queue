module Alephant
  module Publisher
    module Queue
      class Publisher
        include Alephant::Logger

        VISIBILITY_TIMEOUT = 60
        RECEIVE_WAIT_TIME  = 15

        attr_reader :queue, :executor, :opts, :processor

        def initialize(opts, processor = nil)
          @opts = opts
          @processor = processor

          @queue = Alephant::Publisher::Queue::SQSHelper::Queue.new(
            aws_queue,
            archiver,
            opts.queue[:visibility_timeout] || VISIBILITY_TIMEOUT,
            opts.queue[:receive_wait_time]  || RECEIVE_WAIT_TIME
          )
        end

        def run!
          loop { processor.consume(@queue.message) }
        end

        private

        def archiver
          Alephant::Publisher::Queue::SQSHelper::Archiver.new(archive_cache, archiver_opts)
        end

        def archiver_opts
          options = {
            :async_store         => true,
            :log_archive_message => true,
            :log_validator       => opts.queue[:log_validator]
          }
          options.each do |key, _value|
            options[key] = opts.queue[key] == "true" if whitelist_key(opts.queue, key)
          end
        end

        def whitelist_key(options, key)
          options.key?(key) && key != :log_validator
        end

        def archive_cache
          Alephant::Cache.new(
            opts.writer[:s3_bucket_id],
            opts.writer[:s3_object_path]
          )
        end

        def get_region
          opts.queue[:sqs_account_region] || AWS.config.region
        end

        def sqs_client
          @sqs_client ||= AWS::SQS.new(region: get_region)
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
