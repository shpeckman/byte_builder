# bench/sequences.cr
require "./bench_helper"

ByteBuilder.define bench_cell(row, col, r, name), "\e[#{row};#{col}H\e[38;2;#{int3(r)};#{int3(r)};#{int3(r)}m#{name}"

ByteBuilder.define bench_move(row, col), "\e[#{row};#{col}H"

CELL_TEMPLATE = ByteBuilder::Template.new("\e[{0};{1}H\e[38;2;{2:int3};{2:int3};{2:int3}m{3}")

rows   = Array.new(Bench::BATCH * 2) { |i| (i * 7) % 200 + 1 }
name   = "label"
absent = nil.as(Int32?)
b      = ByteBuilder.new(1 << 16)
memory = IO::Memory.new(1 << 16)

Bench.group("cursor move and rgb colour, #{Bench::BATCH} per iteration") do |job|
  job.report("interpolation + str") do
    b.reset
    Bench::BATCH.times do |i|
      row = rows.unsafe_fetch(i)
      col = rows.unsafe_fetch(i + Bench::BATCH)
      r   = col & 255
      b.str("\e[#{row};#{col}H\e[38;2;#{r};#{r};#{r}m#{name}")
    end
    Bench.keep(b)
  end
  job.report("IO::Memory <<") do
    memory.clear
    Bench::BATCH.times do |i|
      row = rows.unsafe_fetch(i)
      col = rows.unsafe_fetch(i + Bench::BATCH)
      r   = col & 255
      memory << "\e[" << row << ';' << col << "H\e[38;2;" << r << ';' << r << ';' << r << 'm' << name
    end
    Bench.keep(memory)
  end
  job.report("chained appends") do
    b.reset
    Bench::BATCH.times do |i|
      row = rows.unsafe_fetch(i)
      col = rows.unsafe_fetch(i + Bench::BATCH)
      r   = col & 255
      b.str("\e[").int(row).semi.int(col).str("H\e[38;2;").int3(r).semi.int3(r).semi.int3(r).char('m').str(name)
    end
    Bench.keep(b)
  end
  job.report("bbwrite") do
    b.reset
    Bench::BATCH.times do |i|
      row = rows.unsafe_fetch(i)
      col = rows.unsafe_fetch(i + Bench::BATCH)
      r   = col & 255
      bbwrite b, "\e[#{row};#{col}H\e[38;2;#{r};#{r};#{r}m#{name}"
    end
    Bench.keep(b)
  end
  job.report("bbwrite with int3 hints") do
    b.reset
    Bench::BATCH.times do |i|
      row = rows.unsafe_fetch(i)
      col = rows.unsafe_fetch(i + Bench::BATCH)
      r   = col & 255
      bbwrite b, "\e[#{row};#{col}H\e[38;2;#{int3(r)};#{int3(r)};#{int3(r)}m#{name}"
    end
    Bench.keep(b)
  end
  job.report("defined template") do
    b.reset
    Bench::BATCH.times do |i|
      row = rows.unsafe_fetch(i)
      col = rows.unsafe_fetch(i + Bench::BATCH)
      b.bench_cell(row, col, col & 255, name)
    end
    Bench.keep(b)
  end
  job.report("bbwrite nesting a defined template") do
    b.reset
    Bench::BATCH.times do |i|
      row = rows.unsafe_fetch(i)
      col = rows.unsafe_fetch(i + Bench::BATCH)
      r   = col & 255
      bbwrite b, "#{bench_move(row, col)}\e[38;2;#{int3(r)};#{int3(r)};#{int3(r)}m#{name}"
    end
    Bench.keep(b)
  end
  job.report("runtime template") do
    b.reset
    Bench::BATCH.times do |i|
      row = rows.unsafe_fetch(i)
      col = rows.unsafe_fetch(i + Bench::BATCH)
      b.format(CELL_TEMPLATE, row, col, col & 255, name)
    end
    Bench.keep(b)
  end
end

Bench.group("control string with optional fields, #{Bench::BATCH} per iteration") do |job|
  job.report("interpolation + str") do
    b.reset
    Bench::BATCH.times do |i|
      columns = rows.unsafe_fetch(i)
      control = "a=p,i=#{i}"
      control = "#{control},c=#{columns}" if columns
      control = "#{control},r=#{absent}" if absent
      control = "#{control},z=#{columns}"
      b.str("\e_G#{control}\e\\")
    end
    Bench.keep(b)
  end
  job.report("chained field") do
    b.reset
    Bench::BATCH.times do |i|
      columns = rows.unsafe_fetch(i)
      b.apc.str("Ga=p,i=").int(i).field(",c=", columns).field(",r=", absent).field(",z=", columns).st
    end
    Bench.keep(b)
  end
  job.report("bbwrite with conditional branches") do
    b.reset
    Bench::BATCH.times do |i|
      columns = rows.unsafe_fetch(i)
      bbwrite b, "\e_Ga=p,i=#{i}#{",c=#{columns}" if columns}#{",r=#{absent}" if absent},z=#{columns}\e\\"
    end
    Bench.keep(b)
  end
  job.report("bbwrite with field hints") do
    b.reset
    Bench::BATCH.times do |i|
      columns = rows.unsafe_fetch(i)
      bbwrite b, "\e_Ga=p,i=#{i}#{field(",c=", columns)}#{field(",r=", absent)}#{field(",z=", columns)}\e\\"
    end
    Bench.keep(b)
  end
end

Bench.group("separated list of 8 strings, #{Bench::BATCH} per iteration") do |job|
  mimes = Array.new(8) { |i| "application/x-type-#{i}" }
  job.report("interpolation + join") do
    b.reset
    Bench::BATCH.times { b.str("\e]52;#{mimes.join(' ')}\e\\") }
    Bench.keep(b)
  end
  job.report("chained appends in a loop") do
    b.reset
    Bench::BATCH.times do
      b.osc(52)
      mimes.each_with_index do |mime, index|
        b.byte(0x20_u8) if index > 0
        b.str(mime)
      end
      b.st
    end
    Bench.keep(b)
  end
  job.report("bbwrite with each") do
    b.reset
    Bench::BATCH.times { bbwrite b, "\e]52;#{each(mimes, ' ') { |mime| "#{mime}" }}\e\\" }
    Bench.keep(b)
  end
end
