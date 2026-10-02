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
end
