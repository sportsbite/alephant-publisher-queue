module Alephant
  module Publisher
    module Queue
      class BaseProcessor
        def consume(_msg)
          raise NotImplementedError.new(
            "You must implement the #consume(msg) method"
          )
        end
      end
    end
  end
end
