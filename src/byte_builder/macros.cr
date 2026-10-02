# src/byte_builder/macros.cr
class ByteBuilder
  macro write(builder, text)
    bbwrite({{builder}}, {{text}})
  end

  macro expand(builder, text, mode, parameters, taken, target = nil)
    {% source = text.is_a?(Path) ? text.resolve : text %}
    {% unless source.is_a?(StringInterpolation) || source.is_a?(StringLiteral) %}
      {% text.raise "bbwrite expects a string literal or a constant holding one, not #{text.class_name.id}" %}
    {% end %}
    {% pieces = [] of ASTNode %}
    {% for piece in (source.is_a?(StringInterpolation) ? source.expressions : [source]) %}
      {% if piece.is_a?(StringLiteral) && !pieces.empty? && pieces.last.is_a?(StringLiteral) %}
        {% pieces[pieces.size - 1] = pieces.last + piece %}
      {% else %}
        {% pieces << piece %}
      {% end %}
    {% end %}
    {% appenders = ::ByteBuilder.methods.select { |method| method.annotation(::ByteBuilder::Appender) } %}
    {% shadowed = parameters.split(",") %}
    {% ambiguous = taken.split(",") %}
    {% slots = [] of StringLiteral %}
    {% terms = [] of StringLiteral %}
    {% lines = [] of StringLiteral %}
    {% statics = [] of NumberLiteral %}
    {% opaque = [] of BoolLiteral %}
    {% for piece in pieces %}
      {% if piece.is_a?(StringLiteral) %}
        {% size = 0 %}
        {% for char in piece.chars %}
          {% code = char.ord %}
          {% size += code < 0x80 ? 1 : (code < 0x800 ? 2 : (code < 0x10000 ? 3 : 4)) %}
        {% end %}
        {% statics << size %}
        {% terms << "" %}
        {% opaque << false %}
        {% lines << (size > 0 ? "__bbb.unsafe_str(#{piece})" : "") %}
      {% else %}
        {% condition = nil %}
        {% positive = nil %}
        {% negative = nil %}
        {% if piece.is_a?(If) %}
          {% condition = piece.cond %}
          {% positive = piece.then %}
          {% negative = piece.else %}
        {% elsif piece.is_a?(And) %}
          {% condition = piece.left %}
          {% positive = piece.right %}
        {% end %}
        {% positive_text = positive.is_a?(StringLiteral) || positive.is_a?(StringInterpolation) %}
        {% negative_text = negative.is_a?(StringLiteral) || negative.is_a?(StringInterpolation) %}
        {% branching = !condition.nil? && ((positive_text && (negative_text || negative.nil?)) || (positive.nil? && negative_text)) %}
        {% looping = false %}
        {% if piece.is_a?(Call) && piece.block && piece.name == "each" %}
          {% bare = piece.receiver.is_a?(Nop) && !piece.global? && !shadowed.includes?("each") %}
          {% own = !piece.receiver.is_a?(Nop) && piece.receiver.id == builder.id %}
          {% looping = bare || own %}
          {% if bare && ambiguous.includes?("each") %}
            {% piece.raise "'each' is ambiguous: it is the bbwrite loop and a method available here. Write #{builder}.each(...) { ... } for the loop, or (each(...) { ... }) for your own method." %}
          {% end %}
        {% end %}
        {% start = slots.size %}
        {% if branching %}
          {% yes = positive_text ? "::ByteBuilder.expand(#{builder}, #{positive}, \"values\", #{parameters}, #{taken})" : "nil" %}
          {% no = negative_text ? "::ByteBuilder::Else.new(::ByteBuilder.expand(#{builder}, #{negative}, \"values\", #{parameters}, #{taken}))" : "nil" %}
          {% slots << "((#{condition}) ? #{yes.id} : #{no.id})" %}
          {% term = "" %}
          {% line = "" %}
          {% if positive_text %}
            {% term = "(::ByteBuilder.on_then(__bbv[#{start}]) { |__bbv| ::ByteBuilder.expand(#{builder}, #{positive}, \"bound\", #{parameters}, #{taken}) })" %}
            {% line = "::ByteBuilder.on_then(__bbv[#{start}]) do |__bbv|\n::ByteBuilder.expand(#{builder}, #{positive}, \"unsafe\", #{parameters}, #{taken})\n0\nend\n" %}
          {% end %}
          {% if negative_text %}
            {% term = (term.empty? ? "" : term + " + ") + "(::ByteBuilder.on_else(__bbv[#{start}]) { |__bbv| ::ByteBuilder.expand(#{builder}, #{negative}, \"bound\", #{parameters}, #{taken}) })" %}
            {% line = line + "::ByteBuilder.on_else(__bbv[#{start}]) do |__bbv|\n::ByteBuilder.expand(#{builder}, #{negative}, \"unsafe\", #{parameters}, #{taken})\n0\nend\n" %}
          {% end %}
          {% statics << 0 %}
          {% terms << term %}
          {% opaque << false %}
          {% lines << line %}
        {% elsif looping %}
          {% if mode != "write" %}
            {% piece.raise "an each loop has no size known in advance, so it cannot be used inside ByteBuilder.define or inside a conditional branch" %}
          {% end %}
          {% body = piece.block.body %}
          {% unless body.is_a?(StringLiteral) || body.is_a?(StringInterpolation) %}
            {% piece.raise "the block of each must contain only a string literal, which is written once per item" %}
          {% end %}
          {% if piece.args.size < 1 || piece.args.size > 2 || piece.named_args %}
            {% piece.raise "each takes a collection and an optional separator, then a block: each(items, \", \") { |item| \"...\" }" %}
          {% end %}
          {% for arg in piece.args %}
            {% slots << "#{arg}" %}
          {% end %}
          {% arguments = piece.block.args %}
          {% item = arguments.empty? ? "__bbe" : (arguments.size == 1 ? "#{arguments[0]}" : "(#{arguments.join(", ").id})") %}
          {% separator = piece.args.size == 2 ? "__bbb.put(__bbv[#{start + 1}]) if __bbn > 0\n" : "" %}
          {% statics << 0 %}
          {% terms << "" %}
          {% opaque << true %}
          {% lines << "__bbv[#{start}].each_with_index do |#{item.id}, __bbn|\n#{separator.id}::ByteBuilder.expand(#{builder}, #{body}, \"write\", #{parameters}, #{taken}, __bbb)\nend\n" %}
        {% else %}
        {% overloads = [] of Def %}
        {% name = "" %}
        {% if piece.is_a?(Call) && !piece.block %}
          {% name = piece.name.stringify %}
          {% bare = piece.receiver.is_a?(Nop) && !piece.global? && !shadowed.includes?(name) %}
          {% own = !piece.receiver.is_a?(Nop) && piece.receiver.id == builder.id %}
          {% if bare || own %}
            {% overloads = appenders.select { |method| method.name == piece.name } %}
          {% end %}
          {% if bare && !overloads.empty? && ambiguous.includes?(name) %}
            {% piece.raise "'#{name.id}' is ambiguous: it names a ByteBuilder appender and a method available here. Write #{builder}.#{name.id}(...) for the appender, or (#{name.id}(...)) for your own method." %}
          {% end %}
        {% end %}
        {% if overloads.empty? %}
          {% slots << "#{piece}" %}
          {% statics << 0 %}
          {% terms << "::ByteBuilder.bound(__bbv[#{start}])" %}
          {% opaque << false %}
          {% lines << "__bbb.unsafe_put(__bbv[#{start}])" %}
        {% else %}
          {% named = piece.named_args ? piece.named_args : [] of ASTNode %}
          {% count = piece.args.size %}
          {% if named.empty? %}
            {% fits = overloads.any? do |method|
                 required = method.args.select { |arg| arg.default_value.is_a?(Nop) }.size
                 method.splat_index ? count >= method.splat_index : (required <= count && count <= method.args.size)
               end %}
            {% unless fits %}
              {% piece.raise "appender '#{name.id}' does not take #{count} argument(s): its signatures are #{overloads.map { |method| "#{name.id}(#{method.args.join(", ").id})" }.join(" and ").id}" %}
            {% end %}
          {% end %}
          {% if overloads.all? { |method| method.annotation(::ByteBuilder::Appender)[:staged] } %}
            {% arguments = piece.args.map { |arg| "#{arg}" } + named.map { |arg| "#{arg.name}: #{arg.value}" } %}
            {% slots << "::ByteBuilder.values_#{name.id}(#{arguments.join(", ").id})" %}
            {% statics << 0 %}
            {% terms << "::ByteBuilder.bound_#{name.id}(__bbv[#{start}])" %}
            {% opaque << false %}
            {% lines << "__bbb.unsafe_#{name.id}(__bbv[#{start}])" %}
          {% else %}
            {% for arg in piece.args %}
              {% slots << "#{arg}" %}
            {% end %}
            {% for arg in named %}
              {% slots << "#{arg.value}" %}
            {% end %}
            {% passed = (0...count).map { |offset| "__bbv[#{start + offset}]" } %}
            {% for arg, offset in named %}
              {% passed << "#{arg.name}: __bbv[#{start + count + offset}]" %}
            {% end %}
            {% list = passed.join(", ") %}
            {% if overloads.all? { |method| method.annotation(::ByteBuilder::Appender)[:max] } %}
              {% statics << overloads.map { |method| method.annotation(::ByteBuilder::Appender)[:max] }.sort.last %}
              {% terms << "" %}
              {% opaque << false %}
              {% lines << "__bbb.unsafe_#{name.id}(#{list.id})" %}
            {% elsif overloads.all? { |method| method.annotation(::ByteBuilder::Appender)[:sized] } %}
              {% statics << 0 %}
              {% terms << "::ByteBuilder.bound_#{name.id}(#{list.id})" %}
              {% opaque << false %}
              {% lines << "__bbb.unsafe_#{name.id}(#{list.id})" %}
            {% else %}
              {% if mode != "write" %}
                {% piece.raise "appender '#{name.id}' reports no size, so it cannot be used inside ByteBuilder.define or inside a conditional branch" %}
              {% end %}
              {% statics << 0 %}
              {% terms << "" %}
              {% opaque << true %}
              {% lines << "__bbb.#{name.id}(#{list.id})" %}
            {% end %}
          {% end %}
        {% end %}
        {% end %}
      {% end %}
    {% end %}
    {% total = 0 %}
    {% for static in statics %}
      {% total += static %}
    {% end %}
    {% bound = "#{total}" %}
    {% for term in terms %}
      {% bound = bound + " + " + term unless term.empty? %}
    {% end %}
    {% tuple = slots.empty? ? "::Tuple.new" : "{ " + slots.map { |slot| "(#{slot.id})" }.join(", ") + " }" %}
    {% if mode == "values" %}
      {{tuple.id}}
    {% elsif mode == "bound" %}
      {{bound.id}}
    {% elsif mode == "unsafe" %}
      {% for line in lines %}
        {% unless line.empty? %}
          {{line.id}}
        {% end %}
      {% end %}
    {% else %}
      ::ByteBuilder.bind({{target ? target : builder}}, {{tuple.id}}) do |__bbb, __bbv|
        __bbb.reserve({{bound.id}})
        {% for line, index in lines %}
          {% unless line.empty? %}
            {{line.id}}
          {% end %}
          {% if opaque[index] %}
            {% rest = 0 %}
            {% for static, later in statics %}
              {% rest += static if later > index %}
            {% end %}
            {% remaining = "#{rest}" %}
            {% for term, later in terms %}
              {% remaining = remaining + " + " + term if later > index && !term.empty? %}
            {% end %}
            __bbb.reserve({{remaining.id}})
          {% end %}
        {% end %}
      end
    {% end %}
  end

  macro define(signature, text)
    {% name = signature.name %}
    {% if ::ByteBuilder.has_method?(name.stringify) %}
      {% signature.raise "ByteBuilder already has a method named '#{name}': pick another name for this template" %}
    {% end %}
    {% names = signature.args.map { |arg| arg.is_a?(TypeDeclaration) ? arg.var.stringify : arg.stringify } %}
    class ::ByteBuilder
      @[AlwaysInline]
      def self.values_{{name}}({{signature.args.splat}})
        ::ByteBuilder.expand(self, {{text}}, "values", {{names.join(",")}}, "")
      end

      @[AlwaysInline]
      def self.bound_{{name}}(__bbv) : ::Int32
        ::ByteBuilder.expand(self, {{text}}, "bound", {{names.join(",")}}, "")
      end

      @[AlwaysInline]
      def unsafe_{{name}}(__bbv) : self
        __bbb = self
        ::ByteBuilder.expand(self, {{text}}, "unsafe", {{names.join(",")}}, "")
        self
      end

      @[::ByteBuilder::Appender(staged: true)]
      @[AlwaysInline]
      def {{name}}({{signature.args.splat}}) : self
        __bbv = ::ByteBuilder.values_{{name}}({{names.map(&.id).splat}})
        reserve(::ByteBuilder.bound_{{name}}(__bbv))
        unsafe_{{name}}(__bbv)
      end
    end
  end
end
