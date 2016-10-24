require "crimp"

require "alephant/cache"
require "alephant/lookup"
require "alephant/logger"
require "alephant/sequencer"
require "alephant/support/parser"
require "alephant/renderer"

module Alephant
  module Publisher
    module Queue
      class Writer
        include Alephant::Logger

        attr_reader :config, :message, :cache, :parser

        def initialize(config, message)
          @config   = config
          @message  = message
        end

        def renderer
          @renderer ||= Alephant::Renderer.create(config, data)
        end

        def cache
          @cache ||= Alephant::Cache.new(
            config[:s3_bucket_id],
            config[:s3_object_path]
          )
        end

        def parser
          @parser ||= Alephant::Support::Parser.new(
            config[:msg_vary_id_path]
          )
        end

        def run!
          if component_records_write_successful?
            seq_for(config[:renderer_id]).validate(message) do
              # block needed in sequencer. Need to make optional with `block.given?`
              # https://github.com/BBC-News/alephant-sequencer/blob/master/lib/alephant/sequencer/sequencer.rb#L41
            end
          end
        end

        protected

        def process_components
          views.map { |component, view| write(component, view) }
        end

        def component_records_write_successful?
          process_components.all? { |response| response.respond_to?(:successful) && response.successful? }
        end

        def write(component, view)
          seq_for(component).validate(message) do
            store(
              component,
              view,
              location_for(component),
              :msg_id => message.id
            )
          end.tap do
            logger.info(
              "event"     => "MessageWritten",
              "component" => component,
              "view"      => view,
              "method"    => "#{self.class}#write"
            )
          end
        end

        def store(component, view, location, storage_opts = {})
          logger.info(
            event:        'StoreBeforeRender',
            component:    component,
            view:         view,
            location:     location,
            storage_opts: storage_opts
          )

          render = view.render

          logger.info(
            event:        'StoreAfterRender',
            component:    component,
            view:         view,
            location:     location,
            storage_opts: storage_opts
          )

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

          lookup.write(component, options, seq_id, location).tap do
            logger.info(
              "event"      => "LookupLocationUpdated",
              "component"  => component,
              "options"    => options,
              "sequenceId" => seq_id,
              "location"   => location,
              "method"     => "#{self.class}#write"
            )
          end
        end

        def location_for(component)
          "#{config[:renderer_id]}/#{component}/#{opt_hash}/#{seq_id}"
        end

        def seq_for(id)
          Alephant::Sequencer.create(
            config[:sequencer_table_name],
            :id       => seq_key_from(id),
            :jsonpath => config[:sequence_id_path],
            :keep_all => config[:keep_all_messages] == "true",
            :config   => config
          )
        end

        def seq_key_from(id)
          "#{id}/#{opt_hash}"
        end

        def seq_id
          @seq_id ||= Alephant::Sequencer::Sequencer.sequence_id_from(
            message, config[:sequence_id_path]
          )
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
          Alephant::Lookup.create(config[:lookup_table_name], config)
        end
      end
    end
  end
end
