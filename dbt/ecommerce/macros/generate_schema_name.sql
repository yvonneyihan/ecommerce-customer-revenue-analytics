{#
  Default dbt behavior appends the custom schema as a suffix of the target
  schema (e.g. "public_staging"). Overridden here so models land in exactly
  staging / intermediate / marts -- a clean separation from the legacy views
  sql/03-07 create directly in `public`, with no naming collision between
  the two layers while both exist side by side.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
