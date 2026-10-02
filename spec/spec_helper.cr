# spec/spec_helper.cr
require "spec"
require "base64"
require "../src/byte_builder"

COMPILER = ENV["CRYSTAL"]? || "crystal"

def text(builder : ByteBuilder) : String
  String.new(builder.written)
end

def compile_output(source : String) : String
  program = IO::Memory.new(%(require "../src/byte_builder"\n#{source}\n))
  output  = IO::Memory.new
  status = Process.run(COMPILER,
    ["build", "--no-codegen", "--no-color", "--stdin-filename", File.join(__DIR__, "compile_probe.cr")],
    input: program, output: output, error: output)
  status.success? ? "" : output.to_s
end
