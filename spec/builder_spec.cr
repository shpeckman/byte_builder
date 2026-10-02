# spec/builder_spec.cr
require "./spec_helper"

describe ByteBuilder do
  it "keeps its position across chained appends" do
    builder = ByteBuilder.new
    builder.csi.int(38).semi.int(2).semi.int3(255).semi.int3(7).semi.int3(42).char('m')
    text(builder).should eq("\e[38;2;255;7;42m")
  end

  it "encodes integers of every width" do
    builder = ByteBuilder.new
    [0, 7, 10, 99, 100, 101, 999, 1000, 65535, 1234567, Int32::MAX, -1, -90, Int32::MIN].each do |n|
      builder.reset
      builder.int(n)
      text(builder).should eq(n.to_s)
    end
    builder.reset
    builder.int(UInt32::MAX).semi.int(UInt64::MAX).semi.int(Int64::MIN).semi.int(7_u8).semi.int(-128_i8)
    builder.semi.int(4294967296_i64).semi.int(-4294967295_i64).semi.int(10_000_000_000_u64)
    text(builder).should eq("#{UInt32::MAX};#{UInt64::MAX};#{Int64::MIN};7;-128;4294967296;-4294967295;10000000000")
  end

  it "encodes the two and three digit fast paths" do
    builder = ByteBuilder.new
    100.times { |n| builder.int2(n).semi }
    text(builder).should eq((0...100).join { |n| "#{n};" })
    builder.reset
    256.times { |n| builder.int3(n).semi }
    text(builder).should eq((0...256).join { |n| "#{n};" })
  end

  it "writes multi-byte characters as utf-8" do
    builder = ByteBuilder.new
    builder.char('a').char('é').char('漢').char('🎉')
    text(builder).should eq("aé漢🎉")
  end

  it "grows on every kind of append" do
    builder = ByteBuilder.new(16)
    2000.times { |n| builder.csi.int(n).semi.int3(n % 256).char('é').str("ab").bytes("cd".to_slice).st }
    text(builder).should eq((0...2000).join { |n| "\e[#{n};#{n % 256}éabcd\e\\" })
    builder.capacity.should be >= builder.pos
  end

  it "reserves explicit headroom for unchecked appends" do
    builder = ByteBuilder.new(16)
    builder.reserve(5000)
    5000.times { builder.unsafe_byte(0x79_u8) }
    text(builder).should eq("y" * 5000)
    builder.remaining.should eq(builder.capacity - 5000)
  end

  it "writes prefixed fields and skips nil values" do
    builder = ByteBuilder.new(16)
    absent  = nil.as(Int32?)
    present = 4.as(Int32?)
    builder.str("a=p").field(",c=", present).field(",r=", absent).field(",t=", 's').field(",n=", "x")
    builder.field(",b=", "yz".to_slice).field(",u=", UInt64::MAX)
    text(builder).should eq("a=p,c=4,t=s,n=x,b=yz,u=#{UInt64::MAX}")
  end

  it "dispatches put on the value type" do
    builder = ByteBuilder.new(16)
    builder.put(12).put("s").put('c').put("b".to_slice).put(nil).put(3_u8)
    text(builder).should eq("12scb3")
  end

  it "builds osc, apc, and dcs envelopes" do
    builder = ByteBuilder.new
    builder.osc(21).str("foreground=?").st
    builder.osc("_dnd_code").str("t=q").st
    builder.apc.char('G').st.dcs.st
    text(builder).should eq("\e]21;foreground=?\e\\\e]_dnd_code;t=q\e\\\e_G\e\\\eP\e\\")
  end

  it "matches the standard library base64 encoding" do
    builder = ByteBuilder.new(16)
    40.times do |size|
      data = Bytes.new(size) { |i| (i * 37 + size).to_u8! }
      builder.reset
      builder.base64(data)
      text(builder).should eq(Base64.strict_encode(data))
    end
    builder.reset
    builder.base64("hello")
    text(builder).should eq("aGVsbG8=")
  end

  it "resets without releasing its buffer" do
    builder = ByteBuilder.new(16)
    builder.str("x" * 100)
    capacity = builder.capacity
    builder.reset
    builder.empty?.should be_true
    builder.capacity.should eq(capacity)
  end
end
