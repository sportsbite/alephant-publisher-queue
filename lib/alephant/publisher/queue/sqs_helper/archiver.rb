require "alephant/logger"
require "date"
require "json"

module Alephant
  module Publisher
    module Queue
      module SQSHelper
        class Archiver
          include Logger

          attr_reader :cache, :async, :log_message_body

          def initialize(cache, opts)
            @cache            = cache
            @async            = opts[:async_store]
            @log_message_body = opts[:log_archive_message]
          end

          def see(message)
            return if message.nil?
            message.tap do |m|
              async ? async_store(m) : sync_store(m)
            end
          end

          private

          def async_store(message)
            Thread.new do
              logger.metric "AsynchronouslyArchivedData"
              store message
            end
          end

          def sync_store(message)
            logger.metric "SynchronouslyArchivedData"
            store message
          end

          def store(message)
            msg_body = body_for(message)
            store_item(message).tap do
              logger.info(
                "event"       => "MessageStored",
                "messageBody" => msg_body,
                "method"      => "#{self.class}#store"
              ) if newsbeat_uri? msg_body
            end
          end

          def newsbeat_uri?(msg_body)
            jsb = ::JSON.parse(msg_body)
            msg = ::JSON.parse(jsb["Message"]) if jsb["Message"]

            true if verify_message_content msg
          rescue ::JSON::ParserError
            false
          end

          def verify_message_content(msg)
            !msg.nil? && msg["uri"] && msg["uri"] =~ /content\/asset\/newsbeat/
          end

          def store_item(message)
            cache.put(
              cache_key(message.id),
              message.body,
              meta_for(message)
            )
          end

          def cache_key(id)
            "archive/#{date_key}/#{id}"
          end

          def log_message_parts(id)
            [
              "#{self.class}#store:",
              "'#archive/#{date_key}/#{id}'"
            ]
          end

          def body_for(message)
            log_message_body ? message.body : '{ "Message": "No message body available" }'
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
