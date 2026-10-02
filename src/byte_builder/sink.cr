# src/byte_builder/sink.cr
class ByteBuilder
  class Sink < ::IO
    def initialize(@builder : ByteBuilder)
    end

    def read(slice : Bytes) : NoReturn
      raise ::IO::Error.new("ByteBuilder is write-only")
    end

    def write(slice : Bytes) : Nil
      @builder.bytes(slice)
    end

    def write_byte(byte : UInt8) : Nil
      @builder.byte(byte)
    end
  end

  def io : Sink
    @io ||= Sink.new(self)
  end
end
