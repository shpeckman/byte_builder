# spec/compile_spec.cr
require "./spec_helper"

private PRELUDE = <<-CRYSTAL
  b = ByteBuilder.new
  row = 1
  CRYSTAL

describe "compile-time checks" do
  it "accepts a valid program" do
    compile_output(<<-CRYSTAL).should eq("")
      #{PRELUDE}
      ByteBuilder.define jump(row, col), "\\e[\#{row};\#{col}H"
      bbwrite b, "\\e[\#{row}H\#{int3(row)}\#{jump(row, 2)}\#{1.5}"
      b.format(ByteBuilder::Template.new("{0}"), row)
      CRYSTAL
  end

  it "rejects a variable as the template" do
    output = compile_output(<<-CRYSTAL)
      #{PRELUDE}
      template = "x"
      bbwrite b, template
      CRYSTAL
    output.should contain("bbwrite expects a string literal or a constant holding one, not Var")
  end

  it "rejects a constant that is not a string" do
    output = compile_output(<<-CRYSTAL)
      #{PRELUDE}
      WIDTH = 5
      bbwrite b, WIDTH
      CRYSTAL
    output.should contain("bbwrite expects a string literal or a constant holding one, not Path")
  end

  it "names the type of an unsupported value" do
    output = compile_output(<<-CRYSTAL)
      #{PRELUDE}
      bbwrite b, "\#{[1, 2]}"
      CRYSTAL
    output.should contain("ByteBuilder cannot write a value of type Array(Int32)")
  end

  it "names the unsupported member of a union" do
    output = compile_output(<<-CRYSTAL)
      #{PRELUDE}
      value = rand < 0.5 ? 1 : :symbol
      bbwrite b, "\#{value}"
      CRYSTAL
    output.should contain("ByteBuilder cannot write a value of type Symbol")
  end

  it "rejects an unsupported value passed to put" do
    output = compile_output(<<-CRYSTAL)
      #{PRELUDE}
      b.put({1, 2})
      CRYSTAL
    output.should contain("ByteBuilder cannot write a value of type Tuple(Int32, Int32)")
  end

  it "rejects an unsupported runtime template argument" do
    output = compile_output(<<-CRYSTAL)
      #{PRELUDE}
      b.format(ByteBuilder::Template.new("{0}"), [1])
      CRYSTAL
    output.should contain("ByteBuilder cannot write a value of type Array(Int32)")
  end

  it "reports a hint called with the wrong number of arguments" do
    output = compile_output(<<-CRYSTAL)
      #{PRELUDE}
      bbwrite b, "\#{int3(1, 2)}"
      CRYSTAL
    output.should contain("appender 'int3' does not take 2 argument(s): its signatures are int3(value : Int32)")
  end

  it "reports a hint that collides with a method of the calling class" do
    output = compile_output(<<-CRYSTAL)
      #{PRELUDE}
      class Widget
        def st
          "mine"
        end

        def draw(b)
          bbwrite b, "x\#{st}"
        end
      end
      Widget.new.draw(b)
      CRYSTAL
    output.should contain("'st' is ambiguous: it names a ByteBuilder appender and a method available here")
    output.should contain("Write b.st(...) for the appender, or (st(...)) for your own method.")
  end

  it "reports a hint that collides with an inherited or class method" do
    output = compile_output(<<-CRYSTAL)
      #{PRELUDE}
      class Base
        def int3(value)
          value
        end
      end

      class Child < Base
        def draw(b)
          bbwrite b, "\#{int3(1)}"
        end
      end
      Child.new.draw(b)
      CRYSTAL
    output.should contain("'int3' is ambiguous")
    output = compile_output(<<-CRYSTAL)
      #{PRELUDE}
      module Draw
        def self.hex(value)
          value
        end

        def self.run(b)
          bbwrite b, "\#{hex(1_u8)}"
        end
      end
      Draw.run(b)
      CRYSTAL
    output.should contain("'hex' is ambiguous")
  end

  it "reports a hint that collides with a top-level method" do
    output = compile_output(<<-CRYSTAL)
      #{PRELUDE}
      def pad(value, width)
        value
      end
      bbwrite b, "\#{pad(1, 2)}"
      CRYSTAL
    output.should contain("'pad' is ambiguous")
  end

  it "accepts the unambiguous spellings in a class that defines the same name" do
    compile_output(<<-CRYSTAL).should eq("")
      #{PRELUDE}
      class Widget
        def st
          "mine"
        end

        def draw(b)
          bbwrite b, "\#{(st)}\#{self.st}\#{b.st}\#{int3(1)}"
        end
      end
      Widget.new.draw(b)
      CRYSTAL
  end

  it "rejects a template name that is already taken" do
    output = compile_output(<<-CRYSTAL)
      #{PRELUDE}
      ByteBuilder.define jump(row), "\\e[\#{row}H"
      ByteBuilder.define jump(row, col), "\\e[\#{row};\#{col}H"
      CRYSTAL
    output.should contain("ByteBuilder already has a method named 'jump'")
    output = compile_output(<<-CRYSTAL)
      #{PRELUDE}
      ByteBuilder.define str(row), "\#{row}"
      CRYSTAL
    output.should contain("ByteBuilder already has a method named 'str'")
  end

  it "rejects an appender without a size inside a defined template" do
    output = compile_output(<<-CRYSTAL)
      #{PRELUDE}
      class ByteBuilder
        @[Appender]
        def shout(value : String) : self
          str(value.upcase)
        end
      end
      ByteBuilder.define loud(text), "\#{shout(text)}!"
      b.loud("x")
      CRYSTAL
    output.should contain("appender 'shout' reports no size, so it cannot be used inside ByteBuilder.define")
  end

  it "rejects a field value of an unsupported type" do
    output = compile_output(<<-CRYSTAL)
      #{PRELUDE}
      bbwrite b, "\#{field(",c=", [1])}"
      CRYSTAL
    output.should contain("bound_field")
    output.should contain("Array(Int32)")
  end
end
