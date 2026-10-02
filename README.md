# byte_builder

A growable byte buffer for Crystal with allocation-free appends, and a macro
that turns an interpolated string literal into those appends at compile time.

It is built for code that emits a lot of small, structured byte sequences, such
as terminal escape codes:

```crystal
require "byte_builder"

b = ByteBuilder.new
bbwrite b, "\e[#{row};#{col}H\e[38;2;#{r};#{g};#{b_}m#{label}"
STDOUT.write(b.written)
```

The `bbwrite` line allocates nothing. It reserves space once, then writes the
literal parts and the values straight into the buffer.

## Contents

- [Installation](#installation)
- [The builder](#the-builder)
- [bbwrite](#bbwrite)
- [Hints](#hints)
- [Conditional branches](#conditional-branches)
- [Loops](#loops)
- [Named templates](#named-templates)
- [Runtime templates](#runtime-templates)
- [Ambiguous hints](#ambiguous-hints)
- [Base64](#base64)
- [Using it as an IO](#using-it-as-an-io)
- [Writing your own appenders](#writing-your-own-appenders)
- [Limits](#limits)
- [Choosing an approach](#choosing-an-approach)
- [Development](#development)

## Installation

Add the shard to `shard.yml` and run `shards install`:

```yaml
dependencies:
  byte_builder:
    github: shpeckman/byte_builder
```

Crystal 1.21 or newer is required. The shard has no dependencies.

## The builder

`ByteBuilder` owns one buffer that doubles when it runs out of room.

```crystal
b = ByteBuilder.new        # 4096 bytes to start
b = ByteBuilder.new(64)    # or choose the initial capacity

b.csi.int(12).semi.int(40).char('H')
b.written                  # => Bytes, a view of what has been appended
b.reset                    # forget the contents, keep the buffer
```

Every appender returns the builder, so calls chain. Chaining costs nothing:
the appenders are inlined and a chain compiles to the same code as separate
statements.

### State

| Method                    | Result                                                                                            |
|---------------------------|---------------------------------------------------------------------------------------------------|
| `pos`                     | Number of bytes written.                                                                          |
| `capacity`                | Size of the buffer.                                                                               |
| `remaining`               | `capacity - pos`.                                                                                 |
| `empty?`                  | Whether nothing has been written.                                                                 |
| `written`                 | The written bytes as a `Bytes` view.                                                              |
| `reset`                   | Sets `pos` to zero and keeps the buffer.                                                          |
| `truncate(position)`      | Rolls back to an earlier `pos`. Raises `ArgumentError` if `position` is negative or beyond `pos`. |
| `reserve(count)`          | Makes sure `count` more bytes fit, growing if needed.                                             |
| `shrink(capacity = 4096)` | Reallocates down to `capacity`, or to `pos` if more is in use.                                    |
| `io`                      | A write-only `IO` over the builder. See [Using it as an IO](#using-it-as-an-io).                  |

`written` points into the buffer. An append that grows the buffer, and
`shrink`, both invalidate it, so take the slice after the last append.

### Appenders

| Method                    | Writes                                                                                                                     |
|---------------------------|----------------------------------------------------------------------------------------------------------------------------|
| `byte(UInt8)`             | One byte.                                                                                                                  |
| `char(Char)`              | The character as UTF-8.                                                                                                    |
| `str(String)`             | The string's bytes.                                                                                                        |
| `bytes(Bytes)`            | The slice. A `StaticArray(UInt8, N)` is accepted too.                                                                      |
| `int(value)`              | Any integer from `Int8` to `UInt128`, in decimal.                                                                          |
| `int2(Int32)`             | A value from 0 to 99, without the general digit count.                                                                     |
| `int3(Int32)`             | A value from 0 to 999, without the general digit count.                                                                    |
| `hex(value)`              | An unsigned integer in lowercase hexadecimal, without leading zeros.                                                       |
| `hex2(UInt8)`             | Exactly two lowercase hexadecimal digits.                                                                                  |
| `pad(value, width)`       | An integer, left-padded with zeros to `width` digits. A minus sign is written before the padding.                          |
| `repeat(value, count)`    | A byte or a character `count` times. A count of zero or less writes nothing.                                               |
| `put(value)`              | Any supported value, chosen by its type: integers, floats, `Bool`, `Char`, `String`, `Bytes`, `Nil`. `nil` writes nothing. |
| `field(prefix, value)`    | `prefix` followed by `value`, or nothing at all when `value` is `nil`.                                                     |
| `base64(data)`            | `Bytes` or a `String`, encoded with padding.                                                                               |
| `decode64(data)`          | The bytes that `data` decodes to.                                                                                          |
| `format(template, *args)` | A [runtime template](#runtime-templates).                                                                                  |
| `csi`                     | `ESC [`                                                                                                                    |
| `osc(code)`               | `ESC ]`, the code (`Int32` or `String`), then `;`                                                                          |
| `apc`                     | `ESC _`                                                                                                                    |
| `dcs`                     | `ESC P`                                                                                                                    |
| `st`                      | `ESC \`                                                                                                                    |
| `semi`                    | `;`                                                                                                                        |

`int2` and `int3` trust their range. A value outside it writes wrong digits,
but never more than two or three bytes and never outside the buffer.

Passing `put` or `field` a type that is not supported is a compile error that
names the type.

### Checked and unchecked appends

The appenders above check capacity on every call. Each one that has a size
known in advance also has an `unsafe_` twin that skips the check:

```crystal
b.reserve(3 * values.size)
values.each { |value| b.unsafe_int3(value) }
```

An `unsafe_` call is only safe after a `reserve` that covers it. `bbwrite`
uses these for you, so you rarely need to call them directly. Appending one
character at a time in a loop is the main case where reserving once and using
`unsafe_char` is worth it; for anything else prefer `str`, `repeat` or
`bbwrite`.

## bbwrite

`bbwrite builder, "literal"` is a macro. It splits the string literal into its
plain parts and its `#{...}` parts at compile time and emits one append per
part. No string is built at run time.

```crystal
bbwrite b, "\e[#{row};#{col}H#{name}"
```

expands to roughly:

```crystal
values = {row, col, name}
b.reserve(4 + bound(row) + bound(col) + bound(name))
b.unsafe_str("\e[")
b.unsafe_put(values[0])
b.unsafe_str(";")
b.unsafe_put(values[1])
b.unsafe_str("H")
b.unsafe_put(values[2])
```

Things to know:

- **It returns the builder**, so `bbwrite(b, "...").st` chains.
- **`ByteBuilder.write(b, "...")`** is the same macro under another name.
- **The template must be a literal.** A string literal, a heredoc, or a
  constant holding a string literal all work. A variable is a compile error.
- **Values are evaluated first.** The builder expression, every interpolated
  value and every hint argument are evaluated exactly once, left to right,
  before anything is written. An expression that reads the builder's own state,
  such as `#{b.pos}`, sees the state from before the write.
- **Values are written by type.** Integers, floats, `Bool`, `Char`, `String`,
  `Bytes` and `nil` are supported, as are unions of them. Anything else is a
  compile error naming the type; convert it yourself, for example with `to_s`.

## Hints

A bare call to an appender inside an interpolation is not evaluated as an
expression. It tells `bbwrite` which appender to use:

```crystal
bbwrite b, "\e[38;2;#{int3(r)};#{int3(g)};#{int3(b_)}m"
bbwrite b, "\e_Ga=T,f=100;#{base64(png)}\e\\"
bbwrite b, "#{hex2(red)}#{pad(index, 3)}#{repeat(' ', width)}"
bbwrite b, "a=p#{field(",c=", columns)}#{field(",r=", rows)}"
```

Any appender works as a hint, including [named templates](#named-templates)
and your [own appenders](#writing-your-own-appenders). Named arguments are
passed through.

A call on the builder itself is treated the same way, which is how you spell a
hint explicitly:

```crystal
bbwrite b, "#{b.int3(r)}"
```

Hints stay inside the single reservation: the macro adds each hint's size to
the one `reserve` call.

To call a method of your own that happens to share an appender's name, wrap it
in parentheses or give it a receiver:

```crystal
bbwrite b, "#{(int3(r))}"      # your int3
bbwrite b, "#{self.int3(r)}"   # your int3
```

See [Ambiguous hints](#ambiguous-hints) for what happens when you don't.

## Conditional branches

An interpolation that is an `if`, an `unless`, a ternary or an `&&`, and whose
branches are string literals, is a conditional branch. Each branch is a
template of its own and may contain values, hints and further branches.

```crystal
bbwrite b, "a=p#{",c=#{columns}" if columns}#{",d=A" if free_data}"
bbwrite b, "#{more ? "m=1" : "m=0;#{base64(last)}"}"
bbwrite b, "#{",q=#{quiet}" unless quiet.zero?}"
bbwrite b, "#{transient && ",N=1"}"
```

- The condition is evaluated once, in its place in the source order.
- A branch's values are evaluated only if that branch is taken, so
  `#{",c=#{columns + 1}" if columns}` is safe when `columns` is `nil`.
- A missing branch, or one that is `nil`, writes nothing. With `&&`, a false
  condition writes nothing.
- The whole sequence still uses one reservation.

A conditional whose branches are not string literals is an ordinary value:
`#{wide ? 80 : 40}` writes `80` or `40`.

## Loops

`each` writes a template once per item:

```crystal
bbwrite b, "[#{each(items) { |item| "<#{item}>" }}]"
bbwrite b, "\e]52;#{each(mimes, ' ') { |mime| "#{mime}" }}\e\\"
bbwrite b, "#{each(pairs) { |key, value| "#{key}=#{value};" }}"
```

- The first argument is any collection that responds to `each_with_index`.
- The optional second argument is a separator written between items.
- The block must contain only a string literal. It may use values, hints,
  branches and nested loops.
- Several block parameters destructure each item, as with `Hash#each`.

A loop's size is not known in advance, so the generated code reserves once per
item and once more for whatever follows the loop. For the same reason a loop
cannot be used inside `ByteBuilder.define` or inside a conditional branch.

## Named templates

`ByteBuilder.define` turns a template into a method on the builder:

```crystal
ByteBuilder.define move(row, col), "\e[#{row + 1};#{col + 1}H"
ByteBuilder.define rgb(r : Int32, g : Int32, b : Int32), "\e[38;2;#{int3(r)};#{int3(g)};#{int3(b)}m"

b.move(0, 0).rgb(255, 128, 0)
```

- Parameters may carry type restrictions. Expressions in the template may use
  them freely, and each expression is evaluated once per call.
- A parameter named like an appender is a value inside its template, not a
  hint.
- A named template is itself an appender, so it works as a hint:
  `bbwrite b, "#{move(row, col)}#{label}"`. Nesting costs no extra
  reservation.
- Defining a name that `ByteBuilder` already has is a compile error.
- Mistakes inside a template are reported when the template is first used,
  not where it is defined.

`define` adds methods to `ByteBuilder` for the whole program. Choose names that
will not collide with another library's, for example by prefixing them.

## Runtime templates

When a template is only known at run time, parse it once into a
`ByteBuilder::Template` and write it with `format`:

```crystal
MOVE = ByteBuilder::Template.new("\e[{0};{1}H")
b.format(MOVE, row, col)
```

- `{0}`, `{1}` and so on refer to the arguments by position. An argument may
  be used more than once or not at all.
- `{{` and `}}` write literal braces.
- A placeholder may name a format: `{0:int2}`, `{0:int3}`, `{0:hex}`,
  `{0:hex2}`, `{0:base64}`. Without one, the value is written by its type, as
  with `put`.
- A malformed template raises `ArgumentError` from `Template.new`.
- Too few arguments, or an argument of the wrong type for its format, raises
  `ArgumentError` before anything is written.

`format` is an appender, so it also works as a hint inside `bbwrite`. It is
slower than `bbwrite`, because the arguments are resolved at run time; use it
only when the template cannot be a literal.

## Ambiguous hints

Because a bare call such as `#{st}` or `#{int3(x)}` means "the builder's
appender", it could silently shadow a method of yours with the same name.
`bbwrite` refuses to guess. If the name is also a method that can be called
at that point, compilation stops with:

```
'int3' is ambiguous: it names a ByteBuilder appender and a method available
here. Write b.int3(...) for the appender, or (int3(...)) for your own method.
```

The same applies to `each` when the calling type has an `each` of its own.

The check covers:

- methods of the calling class or module, including private, inherited and
  class methods;
- public top-level methods;
- file-private top-level methods, written as `private def name` in the same
  file as the `bbwrite` call.

The last of these is found by reading the source file, because the compiler
does not expose file-private methods to macros. That has two consequences:

- **False alarms.** Any `private def` in the file with an appender's name
  triggers the error, even one inside a class the call cannot reach. The fix
  is the same: write `b.name(...)` for the appender.
- **Two cases are not detected.** A file-private method that is itself
  generated by a macro does not appear in the source text. And when the
  `bbwrite` call is generated by another macro, there may be no source file to
  read. In both, a bare hint still means the builder's appender.

If in doubt, spell hints with the builder as receiver. That form is never
ambiguous.

## Base64

```crystal
b.base64(png_bytes)
b.decode64("aGVsbG8=")
```

- `base64` writes standard base64 with padding.
- `decode64` accepts padded or unpadded input. Invalid input raises
  `ArgumentError` and leaves the builder's position unchanged.
- `ByteBuilder.base64_chunks(data, limit = 4096) { |chunk, more| ... }` yields
  slices of the raw data sized so that each encodes to at most `limit`
  characters. `more` is `false` for the last one.

```crystal
ByteBuilder.base64_chunks(image) do |chunk, more|
  bbwrite b, "\e_G#{more ? "m=1" : "m=0"};#{base64(chunk)}\e\\"
end
```

## Using it as an IO

`b.io` returns a write-only `IO` that appends to the builder. Use it to hand
the builder to code that writes to an `IO`:

```crystal
value.to_s(b.io)
b.io << "pi=" << 3.14159
```

The adapter is created on first use and reused. Reading from it raises
`IO::Error`. Writes through it are checked appends, so they are safe but
slower than the builder's own methods.

## Writing your own appenders

Reopen `ByteBuilder` and mark the method with the `Appender` annotation. That
makes it usable as a hint. How much `bbwrite` can do with it depends on what
the annotation says.

**No size information.** The method is called as written, and `bbwrite`
reserves again after it. It cannot be used inside `define` or inside a
conditional branch.

```crystal
class ByteBuilder
  @[Appender]
  def shout(text : String) : self
    str(text.upcase)
  end
end
```

**A fixed maximum.** Give `max:` and provide an `unsafe_` twin that writes at
most that many bytes without checking.

```crystal
class ByteBuilder
  @[AlwaysInline]
  def unsafe_percent(value : Int32) : self
    unsafe_int3(value).unsafe_byte(0x25_u8)
  end

  @[Appender(max: 4)]
  def percent(value : Int32) : self
    reserve(4)
    unsafe_percent(value)
  end
end
```

**A size computed from the arguments.** Give `sized: true` and provide both
`ByteBuilder.bound_<name>` and `unsafe_<name>`, taking the same arguments as
the appender. The bound must never be smaller than what the unsafe method
writes.

```crystal
class ByteBuilder
  def self.bound_quoted(text : String) : Int32
    text.bytesize + 2
  end

  def unsafe_quoted(text : String) : self
    unsafe_byte(0x22_u8).unsafe_str(text).unsafe_byte(0x22_u8)
  end

  @[Appender(sized: true)]
  def quoted(text : String) : self
    reserve(ByteBuilder.bound_quoted(text))
    unsafe_quoted(text)
  end
end
```

For a sequence that is just a template, `ByteBuilder.define` generates all of
this for you.

## Limits

- **Size.** A builder holds at most 2 GiB (`Int32::MAX` bytes). Growing past
  that raises `ArgumentError`.
- **Not thread-safe.** A builder has no locking.
- **Templates are literals.** `bbwrite` and `define` need the string in the
  source. Use a runtime template otherwise.
- **Loops are not sized.** `each` cannot appear in `define` or in a
  conditional branch.
- **Ambiguity detection** has the two gaps described under
  [Ambiguous hints](#ambiguous-hints).
- **Top-level names.** The shard defines `ByteBuilder` and the `bbwrite` macro
  at the top level, and `define` adds methods to `ByteBuilder` globally.
- **Internal names.** `ByteBuilder.expand`, `bind`, `on_then`, `on_else` and
  `Else` are public only because generated code calls them. Do not use them
  directly. Generated code also uses locals beginning with `__bb`.

## Choosing an approach

Start from the shape of what you are writing.

```
Is the text of the sequence written in your source code?
│
├╴No, it arrives at run time (configuration, user input)
│ ╰╴ByteBuilder::Template with b.format
│
╰╴Yes
  │
  ├╴Is its shape fixed, apart from the values?
  │ │
  │ ├╴Yes, and it is used in one place
  │ │ ╰╴bbwrite
  │ │
  │ ╰╴Yes, and it is used in several places
  │   ╰╴ByteBuilder.define, then call it or use it as a hint
  │
  ├╴Are some parts present only sometimes?
  │ │
  │ ├╴One value that may be nil, with a fixed prefix
  │ │ ╰╴field hint:            #{field(",c=", columns)}
  │ │
  │ ╰╴Anything else that depends on a condition
  │   ╰╴conditional branch:    #{",c=#{columns}" if columns}
  │
  ├╴Is a part repeated once per item?
  │ │
  │ ├╴Every item is written the same way
  │ │ ╰╴each loop:             #{each(items, ' ') { |item| "#{item}" }}
  │ │
  │ ╰╴Items differ by position, the loop exits early, or it sits inside a define or a conditional branch
  │   ╰╴chained appends in an ordinary loop
  │
  ╰╴Is it one byte, character or number at a time in a tight loop?
    │
    ├╴The same byte or character many times
    │ ╰╴repeat
    │
    ├╴You can bound the total size before the loop
    │ ╰╴reserve once, then the unsafe_ appenders
    │
    ╰╴Otherwise
      ╰╴the checked appenders
```

Inside any template, pick how a value is written:

```
What is the value?
│
├╴An integer known to be 0..99 or 0..999      → int2 / int3 hint
├╴A byte that must be two hex digits          → hex2 hint
├╴An integer that needs leading zeros         → pad hint
├╴Binary data for a text protocol             → base64 hint
├╴Text or a number, written as it is          → no hint: #{value}
├╴Something with its own to_s(io) only        → value.to_s(b.io), outside the template
╰╴A payload too large for one packet          → ByteBuilder.base64_chunks around a bbwrite
```

### What each choice costs

| Choice                                    | Capacity checks                                             | Other effects                                                                                                                                    |
|-------------------------------------------|-------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| `bbwrite`                                 | One for the whole sequence.                                 | Values and hint arguments are evaluated before anything is written.                                                                              |
| Hint with a fixed or computed size        | None of its own; it is counted in the sequence's one check. | Tells the macro the type, so no dispatch on the value.                                                                                           |
| Conditional branch                        | None of its own.                                            | The condition is evaluated once; its outcome is checked when sizing and again when writing. A branch's values are evaluated only if it is taken. |
| `each` loop                               | One per item, plus one for whatever follows the loop.       | Cannot be used in `define` or in a conditional branch.                                                                                           |
| Appender without size information         | Its own, plus one for whatever follows it.                  | Cannot be used in `define` or in a conditional branch.                                                                                           |
| `ByteBuilder.define`                      | One per call. Nested in another template, none of its own.  | Adds a method to `ByteBuilder` for the whole program.                                                                                            |
| Chained appends                           | One per append.                                             | A possible call into the growth path on every append, which stops the compiler keeping the write position in a register across a loop.           |
| `reserve` then `unsafe_` appends          | One, at the `reserve`.                                      | Nothing protects you if the reservation is too small.                                                                                            |
| Runtime template                          | One per `format` call.                                      | Every argument is dispatched on its type at run time, twice: once to size it, once to write it. The slowest of the builder's own options.        |
| `b.io`                                    | One per write.                                              | Each write is a virtual call. Use it only to reach code that needs an `IO`.                                                                      |
| Interpolating into a `String`, then `str` | One.                                                        | Allocates the string and copies it. This is what `bbwrite` exists to avoid.                                                                      |

Effects that apply whichever way you write:

- **Union types are dispatched at run time.** A value typed `Int32?` or
  `Int32 | String` costs a type test per write. A value with one concrete type
  costs none.
- **Floats are dominated by formatting.** The builder gains little over an
  `IO` for them.
- **`int2` and `int3` skip the digit count** and reserve fewer bytes than
  `int`. They are only correct inside their range.
- **Growth copies the buffer.** Give `ByteBuilder.new` a capacity close to
  what you expect, and reuse one builder with `reset` instead of creating one
  per sequence.
- **`reset` keeps the memory, `shrink` gives it back.** After one unusually
  large write, call `shrink` if the builder is long-lived.
- **`written` is a view.** Growing or shrinking invalidates it.

### Measuring

The shard includes a benchmark suite that compares each approach above with
string interpolation, `IO::Memory` and the standard library's `Base64`:

```
shards build bench --release --no-debug
./bin/bench
```

- **Pin the run to one core** on a processor with both performance and
  efficiency cores, so the scheduler does not move it mid-measurement:
  `taskset -c 0 ./bin/bench`.
- **Compare rows within one run.** Two builds of identical code can place a
  small loop differently and shift its timing, so a modest difference between
  two builds is not evidence of a change.

## Development

```
crystal spec
```

The suite includes `spec/compile_spec.cr`, which compiles small programs and
checks the error messages the macros produce. It needs the `crystal` binary on
the path, or its location in the `CRYSTAL` environment variable, and adds
several seconds to the run.

To see what a `bbwrite` call expands to:

```
crystal tool expand -c path/to/file.cr:LINE:COLUMN path/to/file.cr
```

## License

MIT.