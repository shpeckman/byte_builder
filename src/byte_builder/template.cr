# src/byte_builder/template.cr
class ByteBuilder
  class Template
    enum Format : UInt8
      Plain
      Int2
      Int3
      Hex
      Hex2
      Base64
    end

    record Op, offset : Int32, size : Int32, argument : Int32, format : Format

    getter arity : Int32

    @literals : Bytes
    @ops      : Slice(Op)

    def initialize(source : String)
      literals = ByteBuilder.new(source.bytesize)
      ops      = [] of Op
      arity    = 0
      start    = 0
      bytes    = source.to_slice
      i        = 0
      while i < bytes.size
        byte = bytes[i]
        if byte == 0x7B_u8
          if bytes[i + 1]? == 0x7B_u8
            literals.byte(byte)
            i += 2
            next
          end
          close = bytes.index(0x7D_u8, i) || raise ArgumentError.new("unclosed '{' at byte #{i} of template")
          index, format = Template.placeholder(String.new(bytes[i + 1, close - i - 1]), i)
          ops << Op.new(start, literals.pos - start, index, format)
          arity = Math.max(arity, index + 1)
          start = literals.pos
          i     = close + 1
        elsif byte == 0x7D_u8
          unless bytes[i + 1]? == 0x7D_u8
            raise ArgumentError.new("unmatched '}' at byte #{i} of template: write '}}' for a literal brace")
          end
          literals.byte(byte)
          i += 2
        else
          literals.byte(byte)
          i += 1
        end
      end
      ops << Op.new(start, literals.pos - start, -1, Format::Plain) if literals.pos > start
      @literals = literals.written.dup
      @ops      = Slice(Op).new(ops.size) { |index| ops[index] }
      @arity    = arity
    end

    protected def self.placeholder(spec : String, position : Int32) : Tuple(Int32, Format)
      number, _, name = spec.partition(':')
      index = number.to_i?
      if index.nil? || index < 0
        raise ArgumentError.new("placeholder '{#{spec}}' at byte #{position} needs an argument index such as {0}")
      end
      format = name.empty? ? Format::Plain : Format.parse?(name)
      unless format
        raise ArgumentError.new("unknown format '#{name}' at byte #{position}: use one of #{Format.names.map(&.downcase).join(", ")}")
      end
      {index, format}
    end

    def bound(arguments : Tuple) : Int32
      check(arguments.size)
      total = @literals.size
      @ops.each do |op|
        next if op.argument < 0
        total += Template.bound(op.format, arguments[op.argument])
      end
      total
    end

    def unsafe_write(builder : ByteBuilder, arguments : Tuple) : Nil
      check(arguments.size)
      @ops.each do |op|
        builder.unsafe_bytes(@literals[op.offset, op.size])
        next if op.argument < 0
        Template.append(builder, op.format, arguments[op.argument])
      end
    end

    def each_step(& : Bytes, Int32, Format, Bytes? ->) : Nil
      @ops.each_with_index do |op, index|
        following = @ops[index + 1]?
        before    = following && following.size > 0 ? @literals[following.offset, following.size] : nil
        yield @literals[op.offset, op.size], op.argument, op.format, before
      end
    end

    private def check(count : Int32) : Nil
      if count < @arity
        raise ArgumentError.new("template needs #{@arity} argument(s), got #{count}")
      end
    end

    protected def self.bound(format : Format, value) : Int32
      case format
      in .plain?  then ByteBuilder.bound(value)
      in .int2?   then (small(value); 2)
      in .int3?   then (small(value); 3)
      in .hex?    then (unsigned(value); 16)
      in .hex2?   then (octet(value); 2)
      in .base64? then ByteBuilder.bound_base64(data(value))
      end
    end

    protected def self.append(builder : ByteBuilder, format : Format, value) : Nil
      case format
      in .plain?  then builder.unsafe_put(value)
      in .int2?   then builder.unsafe_int2(small(value))
      in .int3?   then builder.unsafe_int3(small(value))
      in .hex?    then builder.unsafe_hex(unsigned(value))
      in .hex2?   then builder.unsafe_hex2(octet(value))
      in .base64? then builder.unsafe_base64(data(value))
      end
    end

    private def self.small(value : Int32) : Int32
      value
    end

    private def self.small(value) : Int32
      raise ArgumentError.new("formats int2 and int3 need an Int32, got #{value.class}")
    end

    private def self.unsigned(value : UInt8 | UInt16 | UInt32 | UInt64) : UInt64
      value.to_u64!
    end

    private def self.unsigned(value) : UInt64
      raise ArgumentError.new("format hex needs an unsigned integer, got #{value.class}")
    end

    private def self.octet(value : UInt8) : UInt8
      value
    end

    private def self.octet(value) : UInt8
      raise ArgumentError.new("format hex2 needs a UInt8, got #{value.class}")
    end

    private def self.data(value : Bytes) : Bytes
      value
    end

    private def self.data(value : String) : Bytes
      value.to_slice
    end

    private def self.data(value) : Bytes
      raise ArgumentError.new("format base64 needs a String or Bytes, got #{value.class}")
    end
  end

  @[AlwaysInline]
  def self.bound_format(template : Template, *arguments) : Int32
    template.bound(arguments)
  end

  @[AlwaysInline]
  def unsafe_format(template : Template, *arguments) : self
    template.unsafe_write(self, arguments)
    self
  end

  @[Appender(sized: true)]
  @[AlwaysInline]
  def format(template : Template, *arguments) : self
    reserve(template.bound(arguments))
    unsafe_format(template, *arguments)
  end

  struct Reader
    @[Parser]
    def scan?(template : Template, *types : *T) forall T
      {% begin %}
        unless template.arity == {{T.size}}
          raise ArgumentError.new("template needs #{template.arity} type(s), got {{T.size}}")
        end
        start = @pos
        {% for type, index in T %}
          value{{index}} = nil.as({{type.instance}}?)
        {% end %}
        template.each_step do |literal, argument, format, before|
          unless match?(literal)
            @pos = start
            return nil
          end
          {% unless T.size == 0 %}
            case argument
            {% for type, index in T %}
              when {{index}}
                value{{index}} = scan_value(format, {{type.instance}}, before)
                if value{{index}}.nil?
                  @pos = start
                  return nil
                end
            {% end %}
            end
          {% end %}
        end
        ::Tuple.new(
          {% for type, index in T %}
            (value{{index}}.nil? ? raise ArgumentError.new("template has no placeholder for argument {{index}}") : value{{index}}),
          {% end %}
        )
      {% end %}
    end

    def scan(template : Template, *types)
      value = scan?(template, *types)
      value.nil? ? fail("text matching the template") : value
    end

    private def scan_value(format : Template::Format, type : T.class, before : Bytes?) : T? forall T
      case format
      in .plain?        then read?(type, before)
      in .int2?, .int3? then int?(small_type(type))
      in .hex?          then hex?(unsigned_type(type))
      in .hex2?         then hex?(octet_type(type), 2)
      in .base64?       then encoded(type, base64)
      end
    end

    private def small_type(type : Int32.class) : Int32.class
      type
    end

    private def small_type(type) : NoReturn
      raise ArgumentError.new("formats int2 and int3 read an Int32, not #{type}")
    end

    {% for type in [UInt8, UInt16, UInt32, UInt64] %}
      private def unsigned_type(type : {{type}}.class) : {{type}}.class
        type
      end
    {% end %}

    private def unsigned_type(type) : NoReturn
      raise ArgumentError.new("format hex reads an unsigned integer, not #{type}")
    end

    private def octet_type(type : UInt8.class) : UInt8.class
      type
    end

    private def octet_type(type) : NoReturn
      raise ArgumentError.new("format hex2 reads a UInt8, not #{type}")
    end

    private def encoded(type : Bytes.class, value : Bytes) : Bytes
      value
    end

    private def encoded(type : String.class, value : Bytes) : String
      String.new(value)
    end

    private def encoded(type, value : Bytes) : NoReturn
      raise ArgumentError.new("format base64 reads a String or Bytes, not #{type}")
    end
  end
end
