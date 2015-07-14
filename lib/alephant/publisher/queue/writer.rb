require 'crimp'

require 'alephant/cache'
require 'alephant/lookup'
require 'alephant/logger'
require 'alephant/sequencer'
require 'alephant/support/parser'
require 'alephant/renderer'

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
          seq_for(id).validate(message) do
            store(id, view, location_for(id), :msg_id => message.id)
          end.tap do
            logger.info(
              "event"     => "MessageWritten",
              "id"        => id,
              "view"      => view,
              "method"    => "#{self.class}#write"
            )
          end
        end

        def store(id, view, location, storage_opts = {})
          render = view.render
          cache.put(location, render, view.content_type, storage_opts).tap do
            logger.info(
              "event"          => "MessageStored",
              "location"       => location,
              "view"           => view,
              "render"         => render.force_encoding("utf-8"),
              "contentType"    => view.content_type,
              "storageOptions" => storage_opts,
              "messageId"      => message.id,
              "method"         => "#{self.class}#store"
            )
          end
          lookup.write(id, options, seq_id, location).tap do
            logger.info(
              "event"      => "LookupLocationUpdated",
              "id"         => id,
              "options"    => options,
              "sequenceId" => seq_id,
              "location"   => location,
              "method"     => "#{self.class}#write"
            )
          end
        end

        def location_for(id)
          "#{config[:renderer_id]}/#{id}/#{opt_hash}/#{seq_id}"
        end

        def batch
          @batch ||= (views.count > 1) ? seq_for(config[:renderer_id]) : nil
        end

        def batch?
          !batch.nil?
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
