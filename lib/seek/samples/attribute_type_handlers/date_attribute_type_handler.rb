module Seek
  module Samples
    module AttributeTypeHandlers
      class DateAttributeTypeHandler < SampleAttributeHandler
        def test_value(value)
          fail 'Not a date time' unless Date.parse(value.to_s)
        end
      end
    end
  end
end
