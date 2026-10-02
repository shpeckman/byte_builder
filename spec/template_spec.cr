# spec/template_spec.cr
require "./spec_helper"

CLEAR = "\e[2J"

module Sequences
  HOME = "\e[H"
end

ByteBuilder.define move(row, col), "\e[#{row};#{col}H"
ByteBuilder.define paint(int : Int32, st : String), "\e[38;5;#{int3(int)}m#{st}\e[0m"
ByteBuilder.define placed(row, col, label), "#{move(row, col)}#{label}"

private def int3(value) : String
  "caller"
end

private class Screen
  getter builder = ByteBuilder.new(16)

  def initialize(@row : Int32, @title : String)
  end

  def render : Nil
    bbwrite @builder, "\e[#{@row};1H#{@title}#{suffix}"
  end

  private def suffix : Char
    '!'
  end
end

describe "ByteBuilder.write" do
  it "turns an interpolated literal into appends" do
    builder = ByteBuilder.new(16)
    row, col, name = 12, 40, "é!"
    bbwrite builder, "\e[#{row};#{col}H#{name}#{'x'}#{name.to_slice}#{row + 1}#{nil}"
    text(builder).should eq("\e[12;40Hé!xé!13")
  end

  it "returns the builder so calls chain" do
    builder = ByteBuilder.new
    bbwrite(builder, "a#{1}").str("b")
    ByteBuilder.write(builder, "c").int(2)
    text(builder).should eq("a1bc2")
  end

  it "accepts plain literals, heredocs, and constants" do
    builder = ByteBuilder.new(16)
    count   = 3
    bbwrite builder, "plain"
    bbwrite builder, CLEAR
    bbwrite builder, Sequences::HOME
    bbwrite builder, <<-TEXT
      rows=#{count}
      TEXT
    bbwrite builder, ""
    text(builder).should eq("plain\e[2J\e[Hrows=3")
  end

  it "treats bare calls to appenders as format hints" do
    builder = ByteBuilder.new(16)
    r, g, b = 255, 7, 42
    bbwrite builder, "\e[38;2;#{int3(r)};#{int3(g)};#{int3(b)}m#{int2(9)}#{base64("hi")}#{byte(0x41_u8)}#{st}"
    text(builder).should eq("\e[38;2;255;7;42m9aGk=A\e\\")
  end

  it "treats calls on the builder itself as appends" do
    builder = ByteBuilder.new(16)
    bbwrite builder, "<#{builder.int3(5)}#{builder.osc("9")}#{builder.capacity}>"
    text(builder).should eq("<5\e]9;16>")
  end

  it "leaves calls with a receiver or parentheses to the caller" do
    builder = ByteBuilder.new(16)
    bbwrite builder, "#{(int3(1))}|#{1.abs}|#{"st".upcase}"
    text(builder).should eq("caller|1|ST")
  end

  it "omits optional fields through the field hint" do
    builder = ByteBuilder.new(16)
    columns = nil.as(Int32?)
    rows    = 4.as(Int32?)
    bbwrite builder, "a=p#{field(",c=", columns)}#{field(",r=", rows)},z=#{rows}#{field(",q=", "s")}!"
    text(builder).should eq("a=p,r=4,z=4,q=s!")
  end

  it "stays within capacity when dynamic pieces precede fixed ones" do
    builder = ByteBuilder.new(16)
    long    = "x" * 5000
    200.times do |n|
      bbwrite builder, "#{long}\e[#{n};#{n}H#{base64(long)}#{int3(n % 256)};#{n}#{long}tail-of-some-length"
    end
    encoded  = Base64.strict_encode(long)
    expected = (0...200).join { |n| "#{long}\e[#{n};#{n}H#{encoded}#{n % 256};#{n}#{long}tail-of-some-length" }
    text(builder).should eq(expected)
    builder.capacity.should be >= builder.pos
  end

  it "evaluates the builder expression and each value once" do
    builder = ByteBuilder.new
    lookups = 0
    values  = 0
    fetch   = -> { lookups += 1; builder }
    bump    = -> { values += 1; values }
    bbwrite fetch.call, "#{bump.call}-#{bump.call}-#{bump.call}"
    lookups.should eq(1)
    text(builder).should eq("1-2-3")
  end

  it "reads instance variables and private methods at the call site" do
    screen = Screen.new(5, "title")
    screen.render
    text(screen.builder).should eq("\e[5;1Htitle!")
  end
end

describe "ByteBuilder.define" do
  it "adds a named template as a chainable method" do
    builder = ByteBuilder.new(16)
    builder.move(3, 4).move(10, 200).str("x")
    text(builder).should eq("\e[3;4H\e[10;200Hx")
  end

  it "lets parameters shadow appender names" do
    builder = ByteBuilder.new(16)
    builder.paint(7, "hi")
    text(builder).should eq("\e[38;5;7mhi\e[0m")
  end

  it "makes the template usable as a hint in other templates" do
    builder = ByteBuilder.new(16)
    builder.placed(2, 9, "ok")
    bbwrite builder, "#{move(1, 1)}#{placed(4, 5, 'c')}"
    text(builder).should eq("\e[2;9Hok\e[1;1H\e[4;5Hc")
  end
end
