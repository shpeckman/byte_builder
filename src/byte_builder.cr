# src/byte_builder.cr
require "./byte_builder/builder"
require "./byte_builder/template"

macro bbwrite(builder, text)
  ::ByteBuilder.write({{builder}}, {{text}})
end
