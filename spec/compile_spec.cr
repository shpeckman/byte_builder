# spec/compile_spec.cr
require "./spec_helper"

describe "compile-time checks" do
  it "accepts a valid program" do
    compile_output(<<-'CRYSTAL').should eq("")
      ByteBuilder.template Semi, ";"
      ByteBuilder.template Move, "\e[#{row : Int32};#{col : Int32}H"
      ByteBuilder.template Title, ";#{text : String}"
      ByteBuilder.template Cell, "#{at : Move}#{shade : ByteBuilder::Hex2}#{title : Title?}\e\\#{params : ByteBuilder::List(UInt8, Semi)}m"
      b = ByteBuilder.new
      b << Cell.new(at: Move.new(row: 1, col: 2), shade: 3_u8, title: nil, params: [1_u8])
      cell = Cell.read(ByteBuilder::Reader.new(b.written))
      cell.at.row + cell.params.size
      CRYSTAL
  end

  it "rejects an unsupported value passed to put" do
    output = compile_output(<<-'CRYSTAL')
      b = ByteBuilder.new
      b.put({1, 2})
      CRYSTAL
    output.should contain("ByteBuilder cannot write a value of type Tuple(Int32, Int32)")
  end

  it "rejects a value that is not a template passed to <<" do
    output = compile_output(<<-'CRYSTAL')
      b = ByteBuilder.new
      b << 5
      CRYSTAL
    output.should contain("ByteBuilder#<< takes a value of a type declared with ByteBuilder.template, not Int32")
  end

  it "rejects a template that is not a string literal" do
    output = compile_output(<<-'CRYSTAL')
      TEXT = "x"
      ByteBuilder.template Broken, TEXT
      CRYSTAL
    output.should contain("ByteBuilder.template expects a string literal, not Path")
  end

  it "rejects a template without text" do
    output = compile_output(<<-'CRYSTAL')
      ByteBuilder.template Broken, ""
      CRYSTAL
    output.should contain("template 'Broken' has no text")
  end

  it "rejects positional construction" do
    output = compile_output(<<-'CRYSTAL')
      ByteBuilder.template Move, "\e[#{row : Int32};#{col : Int32}H"
      Move.new(1, 2)
      CRYSTAL
    output.should contain("missing arguments: row, col")
  end

  it "rejects a hole that is not a typed field" do
    output = compile_output(<<-'CRYSTAL')
      row = 1
      ByteBuilder.template Broken, "\e[#{row}H"
      CRYSTAL
    output.should contain("a template field must be written as 'name : Type', not Var")
  end

  it "rejects a field declared twice" do
    output = compile_output(<<-'CRYSTAL')
      ByteBuilder.template Broken, "#{row : Int32};#{row : Int32}"
      CRYSTAL
    output.should contain("template 'Broken' declares the field 'row' twice")
  end

  it "names a field type that has no encoding" do
    output = compile_output(<<-'CRYSTAL')
      ByteBuilder.template Broken, "#{ratio : Float64}"
      CRYSTAL
    output.should contain("field 'ratio' has type Float64, which has no encoding")
  end

  it "rejects a union field" do
    output = compile_output(<<-'CRYSTAL')
      ByteBuilder.template Broken, "#{value : Int32 | Char}"
      CRYSTAL
    output.should contain("field 'value' has the union type (Char | Int32), which has no encoding")
  end

  it "rejects a format applied to a type it cannot encode" do
    output = compile_output(<<-'CRYSTAL')
      ByteBuilder.template Broken, "#{value : ByteBuilder::Hex(Int32)}"
      CRYSTAL
    output.should contain("field 'value': ByteBuilder::Hex cannot encode Int32: it accepts UInt8, UInt16, UInt32, UInt64")
  end

  it "rejects a string that nothing ends" do
    output = compile_output(<<-'CRYSTAL')
      ByteBuilder.template Broken, "#{name : String}#{count : Int32}"
      CRYSTAL
    output.should contain("field 'name' has no end: a String is read up to the literal text that follows it")
  end

  it "rejects two numbers with nothing between them" do
    output = compile_output(<<-'CRYSTAL')
      ByteBuilder.template Broken, "#{row : Int32}#{col : Int32}"
      CRYSTAL
    output.should contain("field 'row' of template 'Broken' cannot be told apart from what follows it")
  end

  it "rejects a number followed by text that begins with a digit" do
    output = compile_output(<<-'CRYSTAL')
      ByteBuilder.template Broken, "#{row : Int32}0;"
      CRYSTAL
    output.should contain("field 'row' of template 'Broken' cannot be told apart from what follows it")
  end

  it "rejects a number followed by a string or a character" do
    output = compile_output(<<-'CRYSTAL')
      ByteBuilder.template Broken, "#{row : Int32}#{mark : Char}"
      CRYSTAL
    output.should contain("field 'row' of template 'Broken' cannot be told apart from what follows it")
  end

  it "rejects an optional string" do
    output = compile_output(<<-'CRYSTAL')
      ByteBuilder.template Broken, "#{name : String?};"
      CRYSTAL
    output.should contain("field 'name' cannot be optional: a missing String cannot be told apart from an empty one")
  end

  it "rejects an optional field that looks like what follows it" do
    output = compile_output(<<-'CRYSTAL')
      ByteBuilder.template Title, ";#{text : String}"
      ByteBuilder.template Broken, "#{title : Title?};"
      CRYSTAL
    output.should contain("field 'title' of template 'Broken' cannot be told apart from what follows it")
    output = compile_output(<<-'CRYSTAL')
      ByteBuilder.template Broken, "#{row : Int32?}#{col : Int32}"
      CRYSTAL
    output.should contain("field 'row' of template 'Broken' cannot be told apart from what follows it")
  end

  it "checks a nested template against what follows it" do
    output = compile_output(<<-'CRYSTAL')
      ByteBuilder.template Tag, ":#{value : Int32}"
      ByteBuilder.template Inner, "#{count : Int32}#{tag : Tag?}"
      ByteBuilder.template Broken, "#{inner : Inner}:"
      CRYSTAL
    output.should contain("field 'inner' of template 'Broken' cannot be told apart from what follows it")
  end

  it "rejects lists whose items or separator cannot be read back" do
    output = compile_output(<<-'CRYSTAL')
      ByteBuilder.template Semi, ";"
      ByteBuilder.template Broken, "#{names : ByteBuilder::List(String, Semi)}"
      CRYSTAL
    output.should contain("field 'names' cannot be a list of String")
    output = compile_output(<<-'CRYSTAL')
      ByteBuilder.template Broken, "#{values : ByteBuilder::List(Int32, Int32)}"
      CRYSTAL
    output.should contain("the separator of field 'values' must be a template made only of literal text, not Int32")
    output = compile_output(<<-'CRYSTAL')
      ByteBuilder.template Zero, "0"
      ByteBuilder.template Broken, "#{values : ByteBuilder::List(Int32, Zero)}"
      CRYSTAL
    output.should contain("items of field 'values' run into their separator")
    output = compile_output(<<-'CRYSTAL')
      ByteBuilder.template Semi, ";"
      ByteBuilder.template Broken, "#{values : ByteBuilder::List(Int32, Semi)};"
      CRYSTAL
    output.should contain("field 'values' of template 'Broken' cannot be told apart from what follows it")
  end
end
