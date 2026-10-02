# src/byte_builder/template.cr
class ByteBuilder
  macro write(builder, text, shadow = nil)
    {% source = text.is_a?(Path) ? text.resolve : text %}
    {% if source.is_a?(StringInterpolation) %}
      {% pieces = source.expressions %}
    {% elsif source.is_a?(StringLiteral) %}
      {% pieces = [source] %}
    {% else %}
      {% text.raise "ByteBuilder.write expects a string literal or a constant holding one, not #{text.class_name.id}" %}
    {% end %}
    {% appenders = ::ByteBuilder.methods.select { |method| method.annotation(::ByteBuilder::Appender) } %}
    {% kinds = [] of NumberLiteral %}
    {% bounds = [] of NumberLiteral %}
    {% for piece in pieces %}
      {% if piece.is_a?(StringLiteral) %}
        {% size = 0 %}
        {% for char in piece.chars %}
          {% code = char.ord %}
          {% size += code < 0x80 ? 1 : (code < 0x800 ? 2 : (code < 0x10000 ? 3 : 4)) %}
        {% end %}
        {% kinds << 0 %}
        {% bounds << size %}
      {% else %}
        {% overloads = [] of Def %}
        {% if piece.is_a?(Call) && !piece.block %}
          {% bare = piece.receiver.is_a?(Nop) && !piece.global? && !(shadow && shadow.includes?(piece.name.stringify)) %}
          {% if bare || piece.receiver.id == builder.id %}
            {% overloads = appenders.select { |method| method.name == piece.name } %}
          {% end %}
        {% end %}
        {% if overloads.empty? %}
          {% kinds << 1 %}
          {% bounds << 0 %}
        {% elsif overloads.all? { |method| method.annotation(::ByteBuilder::Appender)[:max] } %}
          {% kinds << 2 %}
          {% bounds << overloads.map { |method| method.annotation(::ByteBuilder::Appender)[:max] }.sort.last %}
        {% elsif !piece.named_args && overloads.all? { |method| method.annotation(::ByteBuilder::Appender)[:sized] } %}
          {% kinds << 4 %}
          {% bounds << 0 %}
        {% else %}
          {% kinds << 3 %}
          {% bounds << 0 %}
        {% end %}
      {% end %}
    {% end %}
    {% total = 0 %}
    {% for bound in bounds %}
      {% total += bound %}
    {% end %}
    %builder = {{builder}}
    {% for piece, index in pieces %}
      {% if kinds[index] == 1 %}
        %value{index} = {{piece}}
      {% elsif kinds[index] == 4 %}
        {% for arg, position in piece.args %}
          %arg{index, position} = {{arg}}
        {% end %}
      {% end %}
    {% end %}
    %builder.reserve({{total}}{% for piece, index in pieces %}{% if kinds[index] == 1 %} + ::ByteBuilder.bound(%value{index}){% elsif kinds[index] == 4 %} + ::ByteBuilder.bound_{{piece.name}}({% for arg, position in piece.args %}%arg{index, position}, {% end %}){% end %}{% end %})
    {% for piece, index in pieces %}
      {% if kinds[index] == 0 %}
        {% if bounds[index] > 0 %}
          %builder.unsafe_str({{piece}})
        {% end %}
      {% elsif kinds[index] == 1 %}
        %builder.unsafe_put(%value{index})
      {% elsif kinds[index] == 2 %}
        %builder.unsafe_{{piece.name}}({{piece.args.splat}})
      {% elsif kinds[index] == 4 %}
        %builder.unsafe_{{piece.name}}({% for arg, position in piece.args %}%arg{index, position}, {% end %})
      {% else %}
        {% rest = 0 %}
        {% for bound, later in bounds %}
          {% rest += bound if later > index %}
        {% end %}
        %builder.{{piece.name}}({{piece.args.splat}}{% if piece.named_args %}, {{piece.named_args.splat}}{% end %})
        %builder.reserve({{rest}}{% for other, later in pieces %}{% if later > index %}{% if kinds[later] == 1 %} + ::ByteBuilder.bound(%value{later}){% elsif kinds[later] == 4 %} + ::ByteBuilder.bound_{{other.name}}({% for arg, position in other.args %}%arg{later, position}, {% end %}){% end %}{% end %}{% end %})
      {% end %}
    {% end %}
    %builder
  end

  macro define(signature, text)
    {% names = signature.args.map { |arg| arg.is_a?(TypeDeclaration) ? arg.var.stringify : arg.stringify } %}
    class ::ByteBuilder
      @[::ByteBuilder::Appender]
      def {{signature.name}}({{signature.args.splat}}) : self
        ::ByteBuilder.write(self, {{text}}, {{names}})
      end
    end
  end
end
