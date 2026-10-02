# spec/spec_helper.cr
require "spec"
require "base64"
require "../src/byte_builder"

def text(builder : ByteBuilder) : String
  String.new(builder.written)
end
