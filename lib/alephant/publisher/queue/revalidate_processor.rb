require "faraday"
require "aws-sdk"
require "crimp"
require "alephant/publisher/queue/processor"
require "alephant/publisher/queue/writer"

module Alephant
  module Publisher
    module Queue
      class RevalidateProcessor < Processor
        attr_reader :opts, :url_generator

        def initialize(opts = nil, url_generator)
          @opts          = opts
          @url_generator = url_generator
        end

        def consume(message)
          return if message.nil?

          http_response = get(message)
          http_message  = build_http_message(message, http_response)

          write(http_message)

          message.delete
          cache.delete(inflight_message_key(message))
        end

        private

        # NOTE: If you change this, you'll need to change this in
        #       `alephant-broker` also.
        def inflight_message_key(message)
          opts = JSON.parse(message.body)
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
          url = url_generator.generate(JSON.parse(message.body))
          res = Faraday.get(url)
          res.body
        end
      end
    end
  end
end
