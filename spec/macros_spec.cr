# spec/macros_spec.cr
require "./spec_helper"

CLEAR = "\e[2J"

module Sequences
  HOME = "\e[H"
end

class ByteBuilder
  @[Appender]
  def shout(value : String) : self
    str(value.upcase)
  end
end

ByteBuilder.define move(row, col), "\e[#{row};#{col}H"
ByteBuilder.define cell(row, col), "\e[#{row + 1};#{col + 1}H"
ByteBuilder.define paint(int : Int32, st : String), "\e[38;5;#{int3(int)}m#{st}\e[0m"
ByteBuilder.define placed(row, col, label), "#{move(row, col)}#{label}"
ByteBuilder.define tagged(key : String, value), "<#{field(prefix: key, value: value)}#{base64(key)}>"
ByteBuilder.define counted(counter), "#{counter.call}:#{counter.call}"

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

private class Painter
  getter builder = ByteBuilder.new(16)

  def int3(value : Int32) : String
    "mine#{value}"
  end

  def st : String
    "own"
  end

  def render : Nil
    bbwrite @builder, "#{(int3(1))}|#{self.st}|#{@builder.int3(2)}#{@builder.st}"
  end
end

describe "bbwrite" do
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

  it "keeps escapes, quotes, and literal interpolation markers intact" do
    builder = ByteBuilder.new(16)
    value   = 1
    bbwrite builder, "\e\\\"q\"\t\#{value}\u{1F600}\0#{value}\e]8;;\a"
    text(builder).should eq("\e\\\"q\"\t\#{value}\u{1F600}\0" + "1\e]8;;\a")
  end

  it "writes every supported value type" do
    builder = ByteBuilder.new(16)
    wide    = Int128::MIN
    maybe   = rand < 2 ? 5 : nil
    bbwrite builder, "#{1.5}|#{true}|#{false}|#{wide}|#{3_u8}|#{maybe}|#{-2.5_f32}|#{UInt128::MAX}"
    text(builder).should eq("1.5|true|false|#{Int128::MIN}|3|5|-2.5|#{UInt128::MAX}")
  end

  it "treats bare calls to appenders as format hints" do
    builder = ByteBuilder.new(16)
    r, g, b = 255, 7, 42
    bbwrite builder, "\e[38;2;#{int3(r)};#{int3(g)};#{int3(b)}m#{int2(9)}#{base64("hi")}#{byte(0x41_u8)}#{st}"
    bbwrite builder, "#{hex2(0xab_u8)}#{hex(4096_u32)}#{pad(7, 3)}#{repeat('-', 3)}#{repeat(0x2E_u8, 2)}#{decode64("aGk=")}"
    text(builder).should eq("\e[38;2;255;7;42m9aGk=A\e\\ab1000007---..hi")
  end

  it "passes named arguments through to hints" do
    builder = ByteBuilder.new(16)
    bbwrite builder, "a#{field(prefix: ",c=", value: 4)}#{pad(width: 4, value: 12)}#{repeat(count: 2, value: 'x')}"
    text(builder).should eq("a,c=40012xx")
  end

  it "treats calls on the builder itself as appends" do
    builder = ByteBuilder.new(16)
    bbwrite builder, "<#{builder.int3(5)}#{builder.osc("9")}#{builder.capacity}>"
    text(builder).should eq("<5\e]9;16>")
  end

  it "leaves parenthesised calls and calls with a receiver to the caller" do
    painter = Painter.new
    painter.render
    text(painter.builder).should eq("mine1|own|2\e\\")
  end

  it "omits optional fields through the field hint" do
    builder = ByteBuilder.new(16)
    columns = nil.as(Int32?)
    rows    = 4.as(Int32?)
    bbwrite builder, "a=p#{field(",c=", columns)}#{field(",r=", rows)},z=#{rows}#{field(",q=", "s")}!"
    text(builder).should eq("a=p,r=4,z=4,q=s!")
  end

  it "evaluates the builder and every value and argument once, in source order" do
    builder = ByteBuilder.new(16)
    calls   = [] of Int32
    lookups = 0
    fetch   = -> { lookups += 1; builder }
    note    = ->(value : Int32) { calls << value; value }
    bbwrite fetch.call, "#{note.call(1)}#{int3(note.call(2))}#{note.call(3)}#{field(",", note.call(4))}#{move(note.call(5), note.call(6))}#{pad(note.call(7), note.call(8))}#{note.call(9)}"
    lookups.should eq(1)
    calls.should eq([1, 2, 3, 4, 5, 6, 7, 8, 9])
    text(builder).should eq("123,4\e[5;6H000000079")
  end

  it "reserves again after an appender that reports no size" do
    builder = ByteBuilder.new(16)
    long    = "y" * 3000
    50.times do |n|
      bbwrite builder, "#{long}#{shout("quiet")}#{str(long)}#{field(";", long)}#{n}#{shout(long)}#{int3(n)}tail"
    end
    expected = (0...50).join { |n| "#{long}QUIET#{long};#{long}#{n}#{long.upcase}#{n}tail" }
    text(builder).should eq(expected)
    builder.capacity.should be >= builder.pos
  end

  it "stays within capacity when long values precede fixed pieces" do
    builder = ByteBuilder.new(16)
    long    = "x" * 5000
    200.times do |n|
      bbwrite builder, "#{long}\e[#{n};#{n}H#{base64(long)}#{int3(n % 256)};#{n}#{long}#{repeat('─', n)}tail-of-some-length"
    end
    encoded  = Base64.strict_encode(long)
    expected = (0...200).join { |n| "#{long}\e[#{n};#{n}H#{encoded}#{n % 256};#{n}#{long}#{"─" * n}tail-of-some-length" }
    text(builder).should eq(expected)
    builder.capacity.should be >= builder.pos
  end

  it "works several times inside one captured block" do
    builder = ByteBuilder.new(16)
    job = ->(n : Int32) do
      bbwrite builder, "a#{n}"
      bbwrite builder, "b#{n}#{"s"}#{1.5}"
      bbwrite builder, "c"
      nil
    end
    job.call(1)
    job.call(2)
    text(builder).should eq("a1b1s1.5ca2b2s1.5c")
  end

  it "nests inside its own interpolations" do
    builder = ByteBuilder.new(16)
    other   = ByteBuilder.new(16)
    bbwrite builder, "<#{bbwrite(other, "in#{1}").pos}>"
    text(builder).should eq("<3>")
    text(other).should eq("in1")
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

  it "accepts arbitrary expressions over its parameters" do
    builder = ByteBuilder.new(16)
    builder.cell(0, 0).cell(11, 39)
    text(builder).should eq("\e[1;1H\e[12;40H")
  end

  it "evaluates each interpolated expression once" do
    builder = ByteBuilder.new(16)
    count   = 0
    counter = -> { count += 1; "n#{count}" * 100 }
    builder.counted(counter)
    count.should eq(2)
    text(builder).should eq("#{"n1" * 100}:#{"n2" * 100}")
  end

  it "lets parameters shadow appender names" do
    builder = ByteBuilder.new(16)
    builder.paint(7, "hi")
    text(builder).should eq("\e[38;5;7mhi\e[0m")
  end

  it "passes named arguments to the hints it uses" do
    builder = ByteBuilder.new(16)
    builder.tagged("k=", 5).tagged("z", nil)
    text(builder).should eq("<k=5az0=><eg==>")
  end

  it "is sized, so nesting needs no second reservation" do
    builder = ByteBuilder.new(16)
    long    = "w" * 4000
    30.times do |n|
      bbwrite builder, "#{long}#{placed(n, n + 1, long)}#{move(n, n)}#{cell(n, n)}#{long}#{n}"
    end
    expected = (0...30).join { |n| "#{long}\e[#{n};#{n + 1}H#{long}\e[#{n};#{n}H\e[#{n + 1};#{n + 1}H#{long}#{n}" }
    text(builder).should eq(expected)
    builder.capacity.should be >= builder.pos
  end

  it "exposes the staged pieces of a template" do
    values = ByteBuilder.values_move(3, "four")
    values.should eq({3, "four"})
    ByteBuilder.bound_move(values).should eq(4 + 11 + 4)
    builder = ByteBuilder.new(64)
    builder.unsafe_move(values)
    text(builder).should eq("\e[3;fourH")
  end
end
