require 'alephant/publisher/queue/writer'

module Alephant
  module Publisher
    module Queue
      class RevalidateWriter < Writer
        def renderer
          @renderer ||= proc do
            new_config = config.merge(renderer_id: message_content.fetch(:renderer_id))
            Alephant::Renderer.create(new_config, data)
          end.call
        end

        def run!
          seq_for(config[:renderer_id]).validate(message, &process_components)
        end

        private

        def data
          @data ||= ::JSON.parse(message_content.fetch(:http_response), symbolize_names: true)
        end

        def message_content
          @message_content ||= ::JSON.parse(message.body, symbolize_names: true)
        end
      end
    end
  end
end
