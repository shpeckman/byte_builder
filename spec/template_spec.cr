# spec/template_spec.cr
require "./spec_helper"

describe ByteBuilder::Template do
  it "fills positional placeholders" do
    builder  = ByteBuilder.new(16)
    template = ByteBuilder::Template.new("\e[{0};{1}H{2}")
    template.arity.should eq(3)
    builder.format(template, 12, 40, "label").format(template, 1_u8, -2_i64, 'c')
    text(builder).should eq("\e[12;40Hlabel\e[1;-2Hc")
  end

  it "applies named formats" do
    builder  = ByteBuilder.new(16)
    template = ByteBuilder::Template.new("{0:int3}/{1:int2}/{2:hex}/{3:hex2}/{4:base64}/{5:plain}")
    builder.format(template, 255, 9, 0xbeef_u32, 0x0a_u8, "hi", 1.5)
    text(builder).should eq("255/9/beef/0a/aGk=/1.5")
    builder.reset
    builder.format(template, 7, 42, 0_u8, 0xff_u8, "hello".to_slice, nil)
    text(builder).should eq("7/42/0/ff/aGVsbG8=/")
  end

  it "reuses arguments, skips unused ones, and keeps literal braces" do
    builder  = ByteBuilder.new(16)
    template = ByteBuilder::Template.new("{{{1}}}-{1}-{{literal}}-{3}")
    template.arity.should eq(4)
    builder.format(template, "unused", "x", :ignored.to_s, true)
    text(builder).should eq("{x}-x-{literal}-true")
  end

  it "handles templates without placeholders or without literals" do
    builder = ByteBuilder.new(16)
    builder.format(ByteBuilder::Template.new("plain é text"))
    builder.format(ByteBuilder::Template.new(""))
    builder.format(ByteBuilder::Template.new("{0}{1}"), 1, 2)
    text(builder).should eq("plain é text12")
  end

  it "reserves once for long arguments" do
    builder  = ByteBuilder.new(16)
    template = ByteBuilder::Template.new("<{0}|{1:base64}|{0}>")
    long     = "z" * 4000
    20.times { builder.format(template, long, long) }
    text(builder).should eq("<#{long}|#{Base64.strict_encode(long)}|#{long}>" * 20)
    builder.capacity.should be >= builder.pos
  end

  it "rejects malformed templates" do
    expect_raises(ArgumentError, "unclosed '{'") { ByteBuilder::Template.new("a{0") }
    expect_raises(ArgumentError, "unmatched '}'") { ByteBuilder::Template.new("a}b") }
    expect_raises(ArgumentError, "needs an argument index") { ByteBuilder::Template.new("{name}") }
    expect_raises(ArgumentError, "needs an argument index") { ByteBuilder::Template.new("{}") }
    expect_raises(ArgumentError, "needs an argument index") { ByteBuilder::Template.new("{-1}") }
    expect_raises(ArgumentError, "unknown format 'octal'") { ByteBuilder::Template.new("{0:octal}") }
  end

  it "rejects missing or mistyped arguments without writing" do
    builder  = ByteBuilder.new(16)
    template = ByteBuilder::Template.new("{0:int3}{1:hex}{2:hex2}{3:base64}")
    builder.str("ok")
    expect_raises(ArgumentError, "needs 4 argument(s), got 2") { builder.format(template, 1, 2_u8) }
    expect_raises(ArgumentError, "int2 and int3 need an Int32") { builder.format(template, "1", 2_u8, 3_u8, "x") }
    expect_raises(ArgumentError, "hex needs an unsigned") { builder.format(template, 1, 2, 3_u8, "x") }
    expect_raises(ArgumentError, "hex2 needs a UInt8") { builder.format(template, 1, 2_u8, 3, "x") }
    expect_raises(ArgumentError, "base64 needs a String or Bytes") { builder.format(template, 1, 2_u8, 3_u8, 4) }
    text(builder).should eq("ok")
  end

  it "works as a hint inside bbwrite" do
    builder  = ByteBuilder.new(16)
    template = ByteBuilder::Template.new("[{0}:{1}]")
    row      = 3
    bbwrite builder, "<#{format(template, row, "x" * 50)}>#{row}"
    text(builder).should eq("<[3:#{"x" * 50}]>3")
  end

  it "scans typed captures back out of text" do
    template = ByteBuilder::Template.new("\e[{0};{1}H{2}|{3}")
    reader   = ByteBuilder::Reader.new("\e[12;40Hlabel|é")
    captures = reader.scan(template, Int32, UInt8, String, Char)
    typeof(captures).should eq(Tuple(Int32, UInt8, String, Char))
    captures.should eq({12, 40_u8, "label", 'é'})
    reader.eof?.should be_true
  end

  it "scans named formats" do
    template = ByteBuilder::Template.new("{0:int3}/{1:int2}/{2:hex}/{3:hex2}/{4:base64}/{5:plain}")
    builder  = ByteBuilder.new(16)
    builder.format(template, 255, 9, 0xbeef_u32, 0x0a_u8, "hi", "tail")
    reader = ByteBuilder::Reader.new(builder.written)
    value  = reader.scan?(template, Int32, Int32, UInt32, UInt8, String, Bytes)
    value.should_not be_nil
    if value
      value[0].should eq(255)
      value[1].should eq(9)
      value[2].should eq(0xbeef_u32)
      value[3].should eq(0x0a_u8)
      value[4].should eq("aGk=")
      String.new(value[5]).should eq("tail")
    end
  end

  it "restores the cursor when a scan fails" do
    template = ByteBuilder::Template.new("<{0};{1}>")
    reader   = ByteBuilder::Reader.new("x<1;2]<3;4>")
    reader.byte
    reader.scan?(template, Int32, Int32).should be_nil
    reader.pos.should eq(1)
    expect_raises(ByteBuilder::Reader::Error, "expected text matching the template at byte 1") do
      reader.scan(template, Int32, Int32)
    end
    reader.take(5)
    reader.scan?(template, Int32, Int32).should eq({3, 4})
  end

  it "scans templates without placeholders and repeated placeholders" do
    reader = ByteBuilder::Reader.new("plain1-2")
    reader.scan?(ByteBuilder::Template.new("plain")).should eq(Tuple.new)
    reader.scan?(ByteBuilder::Template.new("{0}-{0}"), Int32).should eq({2})
    reader.eof?.should be_true
  end

  it "rejects scans whose types do not fit the template" do
    reader = ByteBuilder::Reader.new("1 2")
    expect_raises(ArgumentError, "template needs 2 type(s), got 1") do
      reader.scan?(ByteBuilder::Template.new("{0} {1}"), Int32)
    end
    expect_raises(ArgumentError, "template has no placeholder for argument 0") do
      reader.scan?(ByteBuilder::Template.new("1 {1}"), Int32, Int32)
    end
    expect_raises(ArgumentError, "formats int2 and int3 read an Int32, not String") do
      reader.scan?(ByteBuilder::Template.new("{0:int2}"), String)
    end
    expect_raises(ArgumentError, "format hex reads an unsigned integer, not Int32") do
      reader.scan?(ByteBuilder::Template.new("{0:hex}"), Int32)
    end
    expect_raises(ArgumentError, "format hex2 reads a UInt8, not UInt16") do
      reader.scan?(ByteBuilder::Template.new("{0:hex2}"), UInt16)
    end
    expect_raises(ArgumentError, "format base64 reads a String or Bytes, not Int32") do
      reader.scan?(ByteBuilder::Template.new("{0:base64}"), Int32)
    end
  end
end
