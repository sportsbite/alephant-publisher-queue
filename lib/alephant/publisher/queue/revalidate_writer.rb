module Alephant
  module Publisher
    module Queue
      class RevalidateWriter
        include Alephant::Logger

        attr_reader :message

        def initialize(config, message)
          @config  = config
          @message = message
        end

        def run!
          renderer.views.each do |view_id, view|
            store(view_id, view)
            write_lookup_record(view_id)
          end
        end

        def renderer
          @renderer ||= Alephant::Renderer.create(config, http_data)
        end

        def storage
          @storage ||= Alephant::Cache.new(config.fetch(:s3_bucket_id), config.fetch(:s3_object_path))
        end

        def lookup
          @lookup ||= Alephant::Lookup.create(config.fetch(:lookup_table_name), config)
        end

        private

        def write_lookup_record(view_id)
          lookup.write(view_id, http_options.fetch(:options), seq_id, storage_location(view_id))

          logger.info(event:       'LookupLocationUpdated',
                      view_id:     view_id,
                      options:     http_options.fetch(:options),
                      seq_id:      seq_id,
                      location:    storage_location(view_id),
                      renderer_id: config.fetch(:renderer_id),
                      method:      "#{self.class}#write_lookup_record")
        end

        def store(view_id, view)
          storage.put(storage_location(view_id), view.render, view.content_type, storage_opts)

          logger.info(event:        'MessageStored',
                      location:     storage_location(view_id),
                      view_id:      view_id,
                      view:         view,
                      content:      view.render,
                      content_type: view.content_type,
                      storage_opts: storage_opts,
                      renderer_id:  config.fetch(:renderer_id),
                      method:       "#{self.class}#store")
        end

        # NOTE: we _really_ don't care about sequence here - we just _have_ to pass something through
        def seq_id
          1
        end

        def storage_location(view_id)
          [
            config.fetch(:renderer_id),
            view_id,
            Crimp.signature(http_options)
          ].join('/')
        end

        def storage_opts
          { ttl: message_content[:ttl] }
        end

        def config
          @config.merge(renderer_id: message_content.fetch(:renderer_id))
        end

        def http_data
          @http_data ||= ::JSON.parse(message_content.fetch(:http_response), symbolize_names: true)
        end

        def http_options
          @http_options ||= message_content.fetch(:http_options)
        end

        def message_content
          @message_content ||= ::JSON.parse(message.body, symbolize_names: true)
        end
      end
    end
  end
end
