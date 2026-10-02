# src/byte_builder.cr
require "./byte_builder/builder"
require "./byte_builder/base64"
require "./byte_builder/sink"
require "./byte_builder/template"
require "./byte_builder/macros"

macro bbwrite(builder, text)
  {% if @type <= ::ByteBuilder %}
    ::ByteBuilder.expand({{builder}}, {{text}}, "write", "", "")
  {% else %}
    {% names = ::ByteBuilder.methods.select { |method| method.annotation(::ByteBuilder::Appender) }.map(&.name.stringify).uniq + ["each"] %}
    {% taken = names.select { |name| @type.has_method?(name) || @type.class.has_method?(name) || @top_level.has_method?(name) } %}
    {% file = text.filename %}
    {% source = file ? read_file?(file) : nil %}
    {% if source && source.includes?("private def") %}
      {% for found in source.scan(/^[ \t]*private[ \t]+def[ \t]+(?:self\.)?([A-Za-z_][A-Za-z0-9_]*[?!]?)/m) %}
        {% taken << found[1] if names.includes?(found[1]) && !taken.includes?(found[1]) %}
      {% end %}
    {% end %}
    ::ByteBuilder.expand({{builder}}, {{text}}, "write", "", {{taken.join(",")}})
  {% end %}
end
