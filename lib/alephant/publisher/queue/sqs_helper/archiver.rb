require "alephant/logger"
require "date"

module Alephant
  module Publisher
    module Queue
      module SQSHelper
        class Archiver
          include Logger

          attr_reader :cache, :async, :log_message_body

          def initialize(cache, async = true, log_message_body = false)
            @async            = async
            @cache            = cache
            @log_message_body = log_message_body
          end

          def see(message)
            return if message.nil?
            message.tap do |m|
              if async
                async_store(m)
                logger.metric "AsynchronouslyArchivedData"
              else
                store(m)
                logger.metric "SynchronouslyArchivedData"
              end
            end
          end

          private

          def async_store(m)
            Thread.new { store(m) }
          end

          def store(m)
            logger.info store_log_message(m)
            cache.put(cache_key(m.id), m.body, meta_for(m))
          end

          def store_log_message(message)
            log_message_parts(message.id).tap do |parts|
              parts << "(#{message.body})" if log_message_body
            end.join(" ")
          end

          def log_message_parts(id)
            [
              "#{self.class.name}#store:",
              "'#{cache_key(id)}'"
            ]
          end

          def cache_key(id)
            "archive/#{date_key}/#{id}"
          end

          def date_key
            DateTime.now.strftime("%d-%m-%Y_%H")
          end

          def meta_for(m)
            {
              :id        => m.id,
              :md5       => m.md5,
              :logged_at => DateTime.now.to_s,
              :queue     => m.queue.url
            }
          end
        end
      end
    end
  end
end
