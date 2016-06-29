require "faraday"
require "aws-sdk"
require "crimp"
require "alephant/publisher/queue/processor"
require "alephant/publisher/queue/revalidate_writer"
require "json"
require "alephant/logger"

module Alephant
  module Publisher
    module Queue
      class RevalidateProcessor < Processor
        include Alephant::Logger

        attr_reader :opts, :url_generator

        def initialize(opts = nil, url_generator)
          @opts          = opts
          @url_generator = url_generator
        end

        def consume(message)
          return if message.nil?

          http_response = {
            renderer_id:   message_content(message).fetch(:id),
            sequence_id:   Time.now.to_i,
            http_response: get(message)
          }

          http_message  = build_http_message(message, ::JSON.generate(http_response))

          write(http_message)

          message.delete
          cache.delete(inflight_message_key(message))
        end

        private

        def writer_config
          super.merge(:sequence_id_path => "$.sequence_id")
        end

        def write(message)
          RevalidateWriter.new(writer_config, message).run!
        end

        # NOTE: If you change this, you'll need to change this in
        #       `alephant-broker` also.
        def inflight_message_key(message)
          opts = ::JSON.parse(message.body)
          version_cache_key(
            "inflight-#{opts['id']}/#{build_inflight_opts_hash(opts)}"
          )
        end

        def build_inflight_opts_hash(opts)
          opts_hash = Hash[opts["options"].map { |k, v| [k.to_sym, v] }]
          Crimp.signature(opts_hash)
        end

        def version_cache_key(key)
          cache_version = opts.cache[:elasticache_cache_version]
          [key, cache_version].compact.join("_")
        end

        def cache
          @cache ||= proc do
            endpoint = opts.cache.fetch(:elasticache_config_endpoint)
            Dalli::ElastiCache.new(endpoint).client
          end.call
        end

        def build_http_message(message, http_response)
          # I feel dirty...
          # FIXME: refactor `Writer` so it's not so tightly coupled to a AWS::SQS::ReceivedMessage object
          http_message = message.dup
          http_message.instance_variable_set(:@body, http_response)
          http_message
        end

        def get(message)
          url = url_generator.generate(message_content(message))

          logger.info(
            :event  => "Sending HTTP GET request",
            :url    => url,
            :method => "#{self.class}#get"
          )

          res = Faraday.get(url)

          logger.info(
            :event  => "HTTP request complete",
            :url    => url,
            :status => res.status,
            :body   => res.body,
            :method => "#{self.class}#get"
          )

          # TODO: have something to handle the HTTP response

          res.body
        end

        def message_content(message)
          ::JSON.parse(message.body, symbolize_names: true)
        end
      end
    end
  end
end
