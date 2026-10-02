# src/byte_builder/builder.cr
class ByteBuilder
  annotation Appender
  end

  DIGIT_PAIRS = Bytes.new(200) do |i|
    number = i // 2
    (i.even? ? number // 10 : number % 10).to_u8 + 48_u8
  end

  BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".to_slice

  MAX_DIGITS = 20

  private macro fixed(max, signature, &block)
    @[AlwaysInline]
    def unsafe_{{signature.name}}({{signature.args.splat}}) : self
      {{block.body}}
      self
    end

    @[::ByteBuilder::Appender(max: {{max}})]
    @[AlwaysInline]
    def {{signature.name}}({{signature.args.splat}}) : self
      reserve({{max}})
      unsafe_{{signature.name}}({{signature.args.map(&.var).splat}})
    end
  end

  private macro value(type, appender, bound)
    @[AlwaysInline]
    def self.bound(value : {{type}}) : Int32
      {{bound}}
    end

    @[AlwaysInline]
    def put(value : {{type}}) : self
      {{appender.id}}(value)
    end

    @[AlwaysInline]
    def unsafe_put(value : {{type}}) : self
      unsafe_{{appender.id}}(value)
    end
  end

  @buf : Pointer(UInt8)
  @pos : Int32
  @cap : Int32

  def initialize(capacity : Int32 = 4096)
    @cap = Math.max(capacity, 16)
    @buf = Pointer(UInt8).malloc(@cap)
    @pos = 0
  end

  @[AlwaysInline]
  def reset : Nil
    @pos = 0
  end

  @[AlwaysInline]
  def pos : Int32
    @pos
  end

  @[AlwaysInline]
  def capacity : Int32
    @cap
  end

  @[AlwaysInline]
  def remaining : Int32
    @cap - @pos
  end

  @[AlwaysInline]
  def empty? : Bool
    @pos == 0
  end

  @[AlwaysInline]
  def written : Bytes
    Slice.new(@buf, @pos)
  end

  @[AlwaysInline]
  def reserve(count : Int32) : self
    grow(count) if @cap - @pos < count
    self
  end

  fixed 1, byte(value : UInt8) do
    @buf[@pos] = value
    @pos += 1
  end

  fixed 4, char(value : Char) do
    code = value.ord
    if code < 0x80
      @buf[@pos] = code.to_u8!
      @pos += 1
    else
      value.each_byte do |byte|
        @buf[@pos] = byte
        @pos += 1
      end
    end
  end

  fixed 11, int(value : Int8 | Int16 | Int32) do
    magnitude = value.to_u32!
    if value < 0
      @buf[@pos] = 45_u8
      @pos += 1
      magnitude = 0_u32 &- magnitude
    end
    digits32(magnitude)
  end

  fixed 10, int(value : UInt8 | UInt16 | UInt32) do
    digits32(value.to_u32!)
  end

  fixed 20, int(value : Int64) do
    magnitude = value.to_u64!
    if value < 0
      @buf[@pos] = 45_u8
      @pos += 1
      magnitude = 0_u64 &- magnitude
    end
    digits64(magnitude)
  end

  fixed 20, int(value : UInt64) do
    digits64(value)
  end

  fixed 2, int2(value : Int32) do
    if value < 10
      @buf[@pos] = value.to_u8! + 48_u8
      @pos += 1
    else
      pair = value * 2
      @buf[@pos] = DIGIT_PAIRS.unsafe_fetch(pair)
      @buf[@pos + 1] = DIGIT_PAIRS.unsafe_fetch(pair + 1)
      @pos += 2
    end
  end

  fixed 3, int3(value : Int32) do
    if value < 100
      unsafe_int2(value)
    else
      pair = (value % 100) * 2
      @buf[@pos] = (value // 100).to_u8! + 48_u8
      @buf[@pos + 1] = DIGIT_PAIRS.unsafe_fetch(pair)
      @buf[@pos + 2] = DIGIT_PAIRS.unsafe_fetch(pair + 1)
      @pos += 3
    end
  end

  fixed 2, csi do
    pair(0x1B_u8, 0x5B_u8)
  end

  fixed 2, apc do
    pair(0x1B_u8, 0x5F_u8)
  end

  fixed 2, dcs do
    pair(0x1B_u8, 0x50_u8)
  end

  fixed 2, st do
    pair(0x1B_u8, 0x5C_u8)
  end

  fixed 1, semi do
    @buf[@pos] = 0x3B_u8
    @pos += 1
  end

  @[AlwaysInline]
  def unsafe_bytes(value : Bytes) : self
    value.copy_to(@buf + @pos, value.size)
    @pos += value.size
    self
  end

  @[Appender]
  @[AlwaysInline]
  def bytes(value : Bytes) : self
    reserve(value.size)
    unsafe_bytes(value)
  end

  @[Appender]
  @[AlwaysInline]
  def bytes(value : StaticArray(UInt8, N)) : self forall N
    bytes(value.to_slice)
  end

  @[AlwaysInline]
  def unsafe_str(value : String) : self
    unsafe_bytes(value.to_slice)
  end

  @[Appender]
  @[AlwaysInline]
  def str(value : String) : self
    bytes(value.to_slice)
  end

  value Int8 | Int16 | Int32, int, 11
  value UInt8 | UInt16 | UInt32, int, 10
  value Int64 | UInt64, int, 20
  value Char, char, 4
  value String, str, value.bytesize
  value Bytes, bytes, value.size

  @[AlwaysInline]
  def self.bound(value : Nil) : Int32
    0
  end

  @[AlwaysInline]
  def put(value : Nil) : self
    self
  end

  @[AlwaysInline]
  def unsafe_put(value : Nil) : self
    self
  end

  @[Appender]
  @[AlwaysInline]
  def field(prefix : String, value : Nil) : self
    self
  end

  @[Appender]
  @[AlwaysInline]
  def field(prefix : String, value) : self
    reserve(prefix.bytesize + ByteBuilder.bound(value))
    unsafe_str(prefix).unsafe_put(value)
  end

  @[Appender]
  @[AlwaysInline]
  def osc(code : Int32) : self
    reserve(14)
    unsafe_byte(0x1B_u8).unsafe_byte(0x5D_u8).unsafe_int(code).unsafe_semi
  end

  @[Appender]
  @[AlwaysInline]
  def osc(code : String) : self
    reserve(code.bytesize + 3)
    unsafe_byte(0x1B_u8).unsafe_byte(0x5D_u8).unsafe_str(code).unsafe_semi
  end

  @[Appender]
  def base64(data : Bytes) : self
    reserve((data.size + 2) // 3 * 4)
    i = 0
    while i + 2 < data.size
      b0 = data.unsafe_fetch(i)
      b1 = data.unsafe_fetch(i + 1)
      b2 = data.unsafe_fetch(i + 2)
      quad(
        BASE64_CHARS.unsafe_fetch(b0 >> 2),
        BASE64_CHARS.unsafe_fetch(((b0 & 0x03) << 4) | (b1 >> 4)),
        BASE64_CHARS.unsafe_fetch(((b1 & 0x0F) << 2) | (b2 >> 6)),
        BASE64_CHARS.unsafe_fetch(b2 & 0x3F))
      i += 3
    end
    case data.size - i
    when 1
      b0 = data.unsafe_fetch(i)
      quad(
        BASE64_CHARS.unsafe_fetch(b0 >> 2),
        BASE64_CHARS.unsafe_fetch((b0 & 0x03) << 4),
        0x3D_u8, 0x3D_u8)
    when 2
      b0 = data.unsafe_fetch(i)
      b1 = data.unsafe_fetch(i + 1)
      quad(
        BASE64_CHARS.unsafe_fetch(b0 >> 2),
        BASE64_CHARS.unsafe_fetch(((b0 & 0x03) << 4) | (b1 >> 4)),
        BASE64_CHARS.unsafe_fetch((b1 & 0x0F) << 2),
        0x3D_u8)
    end
    self
  end

  @[Appender]
  @[AlwaysInline]
  def base64(data : String) : self
    base64(data.to_slice)
  end

  @[AlwaysInline]
  private def pair(first : UInt8, second : UInt8) : Nil
    @buf[@pos] = first
    @buf[@pos + 1] = second
    @pos += 2
  end

  @[AlwaysInline]
  private def quad(c0 : UInt8, c1 : UInt8, c2 : UInt8, c3 : UInt8) : Nil
    (@buf + @pos).as(Pointer(UInt32)).value =
      c0.to_u32 | (c1.to_u32 << 8) | (c2.to_u32 << 16) | (c3.to_u32 << 24)
    @pos += 4
  end

  @[AlwaysInline]
  private def digits32(value : UInt32) : Nil
    count = if value < 100
              value < 10 ? 1 : 2
            elsif value < 10_000
              value < 1_000 ? 3 : 4
            elsif value < 1_000_000
              value < 100_000 ? 5 : 6
            elsif value < 100_000_000
              value < 10_000_000 ? 7 : 8
            else
              value < 1_000_000_000 ? 9 : 10
            end
    index = @pos + count
    while value >= 100
      pair = (value % 100) * 2
      value //= 100
      index -= 2
      @buf[index] = DIGIT_PAIRS.unsafe_fetch(pair)
      @buf[index + 1] = DIGIT_PAIRS.unsafe_fetch(pair + 1)
    end
    if value >= 10
      pair = value * 2
      @buf[index - 2] = DIGIT_PAIRS.unsafe_fetch(pair)
      @buf[index - 1] = DIGIT_PAIRS.unsafe_fetch(pair + 1)
    else
      @buf[index - 1] = value.to_u8! + 48_u8
    end
    @pos += count
  end

  private def digits64(value : UInt64) : Nil
    if value <= UInt32::MAX
      digits32(value.to_u32!)
      return
    end
    scratch = uninitialized UInt8[MAX_DIGITS]
    digits = scratch.to_unsafe
    index  = MAX_DIGITS
    while value >= 100
      pair = (value % 100).to_i32! * 2
      value //= 100
      index -= 2
      digits[index] = DIGIT_PAIRS.unsafe_fetch(pair)
      digits[index + 1] = DIGIT_PAIRS.unsafe_fetch(pair + 1)
    end
    if value >= 10
      pair = value.to_i32! * 2
      index -= 2
      digits[index] = DIGIT_PAIRS.unsafe_fetch(pair)
      digits[index + 1] = DIGIT_PAIRS.unsafe_fetch(pair + 1)
    else
      index -= 1
      digits[index] = value.to_u8! + 48_u8
    end
    count = MAX_DIGITS - index
    (digits + index).copy_to(@buf + @pos, count)
    @pos += count
  end

  @[NoInline]
  private def grow(count : Int32) : Nil
    needed   = @pos + count
    capacity = @cap
    while capacity < needed
      capacity *= 2
    end
    @buf = @buf.realloc(capacity)
    @cap = capacity
  end
end
