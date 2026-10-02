# bench/integers.cr
require "./bench_helper"

small  = Array.new(Bench::LARGE_BATCH) { |i| (i * 7) % 256 }
mixed  = Array.new(Bench::LARGE_BATCH) { |i| (i &* 2_654_435_761_u32.to_i32!) >> (i % 24) }
wide   = Array.new(Bench::LARGE_BATCH) { |i| (i.to_u64 + 1) &* 72_057_594_037_927_931_u64 }
b      = ByteBuilder.new(1 << 18)
memory = IO::Memory.new(1 << 18)

Bench.group("integers 0..255, #{Bench::LARGE_BATCH} per iteration") do |job|
  job.report("IO::Memory <<") do
    memory.clear
    small.each { |n| memory << n }
    Bench.keep(memory)
  end
  job.report("int") do
    b.reset
    small.each { |n| b.int(n) }
    Bench.keep(b)
  end
  job.report("int3") do
    b.reset
    small.each { |n| b.int3(n) }
    Bench.keep(b)
  end
  job.report("reserve + unsafe_int3") do
    b.reset
    b.reserve(small.size * 3)
    small.each { |n| b.unsafe_int3(n) }
    Bench.keep(b)
  end
end

Bench.group("signed 32-bit integers of mixed length, #{Bench::LARGE_BATCH} per iteration") do |job|
  job.report("IO::Memory <<") do
    memory.clear
    mixed.each { |n| memory << n }
    Bench.keep(memory)
  end
  job.report("int") do
    b.reset
    mixed.each { |n| b.int(n) }
    Bench.keep(b)
  end
end

Bench.group("unsigned 64-bit integers, #{Bench::LARGE_BATCH} per iteration") do |job|
  job.report("IO::Memory <<") do
    memory.clear
    wide.each { |n| memory << n }
    Bench.keep(memory)
  end
  job.report("int") do
    b.reset
    wide.each { |n| b.int(n) }
    Bench.keep(b)
  end
end
