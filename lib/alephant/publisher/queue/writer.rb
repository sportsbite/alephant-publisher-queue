require 'crimp'

require 'alephant/cache'
require 'alephant/lookup'
require 'alephant/logger'
require 'alephant/sequencer'
require 'alephant/support/parser'
require 'alephant/renderer'
require "alephant/renderer/response"

module Alephant
  module Publisher
    module Queue
      class Writer
        include Logger

        attr_reader :config, :message, :cache, :parser, :renderer

        def initialize(config, message)
          @config   = config
          @message  = message
          @renderer = Alephant::Renderer.create(config, data)
        end

        def cache
          @cache ||= Cache.new(
            config[:s3_bucket_id],
            config[:s3_object_path]
          )
        end

        def parser
          @parser ||= Support::Parser.new(
            config[:msg_vary_id_path]
          )
        end

        def run!
          batch? ? batch.validate(message, &perform) : perform.call
        end

        protected

        def perform
          Proc.new { views.each { |id, view| write(id, view) } }
        end

        def write(id, view)
          logger.info "Publisher::Queue::Writer#writes: id '#{id}', view '#{view}'"
          seq_for(id).validate(message) do
            store(id, view, location_for(id))
          end
        end

        def store(id, view, location)
          logger.info "Publisher::Queue::Writer#store: location '#{location}', message.id '#{message.id}'"
          cache.put(location, json_response(view.render), view.content_type, :msg_id => message.id)
          lookup.write(id, options, seq_id, location)
        end

        def json_response(content)
          Alephant::Renderer::Response.new(content).to_json
        end

        def location_for(id)
          "#{config[:renderer_id]}/#{id}/#{opt_hash}/#{seq_id}"
        end

        def batch
          @batch ||= (views.count > 1) ? seq_for(config[:renderer_id]) : nil
        end

        def batch?
          !batch.nil?.tap { |b| logger.info "Publisher::Queue::Writer#batch?: #{b}" }
        end

        def seq_for(id)
          Sequencer.create(
            config[:sequencer_table_name],
            seq_key_from(id),
            config[:sequence_id_path],
            config[:keep_all_messages] == 'true'
          )
        end

        def seq_key_from(id)
          "#{id}/#{opt_hash}"
        end

        def seq_id
          @seq_id ||= Sequencer::Sequencer.sequence_id_from(message, config[:sequence_id_path])
        end

        def views
          @views ||= renderer.views
        end

        def opt_hash
          @opt_hash ||= Crimp.signature(options)
        end

        def options
          @options ||= data[:options]
        end

        def data
          @data ||= parser.parse(message)
        end

        def lookup
          Lookup.create(config[:lookup_table_name])
        end
      end
    end
  end
end
