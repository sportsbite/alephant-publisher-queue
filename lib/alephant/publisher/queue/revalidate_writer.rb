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
            storage_loc = storage_location(view_id)

            # TODO: LOGGING!
            storage.put(storage_loc, view.render, view.content_type, storage_opts)
            lookup.write(view_id, message_content.fetch(:http_options), seq_id, storage_loc)
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

        # NOTE: we _really_ don't care about sequence here - we just _have_ to pass something through
        def seq_id
          1
        end

        def storage_location(view_id)
          [
            config.fetch(:renderer_id),
            view_id,
            Crimp.signature(message_content.fetch(:http_options))
          ].join('/')
        end

        def storage_opts
          {}
        end

        def config
          @config.writer.merge(renderer_id: message_content.fetch(:renderer_id))
        end

        def http_data
          @data ||= ::JSON.parse(message_content.fetch(:http_response), symbolize_names: true)
        end

        def message_content
          @message_content ||= ::JSON.parse(message.body, symbolize_names: true)
        end
      end
    end
  end
end
