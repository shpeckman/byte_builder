# spec/read_spec.cr
require "./spec_helper"

private CURSOR = "\e[#{row : Int32};#{col : Int32}R"

private def cursor(source : String) : Tuple(Int32, Int32)?
  r = ByteBuilder::Reader.new(source)
  return nil unless bbread r, "\e[#{row : Int32};#{col : Int32}R"
  {row, col}
end

describe "bbread" do
  it "reads typed holes between literals" do
    r = ByteBuilder::Reader.new("\e[12;40Hlabel\a")
    if bbread r, "\e[#{row : Int32};#{col : UInt8}H#{label : String}\a"
      typeof(row).should eq(Int32)
      typeof(col).should eq(UInt8)
      row.should eq(12)
      col.should eq(40_u8)
      label.should eq("label")
    else
      fail "expected a match"
    end
    r.eof?.should be_true
  end

  it "restores the cursor when any part fails" do
    r = ByteBuilder::Reader.new("x\e[12;40Q")
    r.byte
    bbread(r, "\e[#{row : Int32};#{col : Int32}H").should be_false
    r.pos.should eq(1)
    row.should eq(12)
    bbread(r, "\e[#{row : Int32};#{col : Int32}Q").should be_true
    r.eof?.should be_true
  end

  it "narrows the holes after a guard" do
    cursor("\e[3;14R").should eq({3, 14})
    cursor("\e[3;R").should be_nil
  end

  it "reads through explicit parsers" do
    r       = ByteBuilder::Reader.new("#ff8000 2026-10 née \e]52;aGk=\e\\")
    matched = bbread r, "##{red = hex2}#{green = hex(UInt8, 2)}#{blue = r.hex2?} #{year = int(Int32, 4)}-#{month = int(Int32, width: 2)} #{word = take_while { |byte| byte != 0x20_u8 }} #{osc(52)}#{payload = base64}#{st}"
    matched.should be_true
    if matched && red && green && blue && year && month && word && payload
      {red, green, blue}.should eq({0xff_u8, 0x80_u8, 0x00_u8})
      {year, month}.should eq({2026, 10})
      String.new(word).should eq("née")
      String.new(payload).should eq("aGk=")
    end
    r.eof?.should be_true
  end

  it "reads a string or bytes hole up to the next literal or the end" do
    r = ByteBuilder::Reader.new("key=a=b; tail")
    if bbread r, "#{key : Bytes}=#{value : String}; #{tail : String}"
      String.new(key).should eq("key")
      value.should eq("a=b")
      tail.should eq("tail")
    else
      fail "expected a match"
    end
    r = ByteBuilder::Reader.new("key")
    bbread(r, "#{key : String}=").should be_false
    r.pos.should eq(0)
  end

  it "discards values and accepts plain literals and constants" do
    r = ByteBuilder::Reader.new("12;é;ok\e[5;6R")
    bbread(r, "#{int(Int32)};#{char};#{take(2)}").should be_true
    r.pos.should eq(8)
    bbread(r, "nope").should be_false
    row = col = 0
    bbread(r, CURSOR).should be_true
    {row, col}.should eq({5, 6})
    bbread(r, "").should be_true
    r.eof?.should be_true
  end

  it "reads back what bbwrite writes" do
    builder = ByteBuilder.new(16)
    bbwrite builder, "\e[#{-3};#{int3(255)}H#{hex(0xbeef_u32)}:#{"text"}|#{'é'}"
    r = ByteBuilder::Reader.new(builder.written)
    if bbread r, "\e[#{a : Int32};#{b : Int32}H#{c = hex(UInt32)}:#{d : String}|#{e : Char}"
      {a, b, c, d, e}.should eq({-3, 255, 0xbeef_u32, "text", 'é'})
    else
      fail "expected a match"
    end
  end
end
