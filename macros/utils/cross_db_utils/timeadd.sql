{# Same as dateadd, but supports timestamps as well and not just dates #}
{% macro timeadd(date_part, number, timestamp_expression) -%}
    {{ return(adapter.dispatch('timeadd', 'elementary')(date_part, number, timestamp_expression)) }}
{%- endmacro %}

{# Snowflake #}
{% macro default__timeadd(date_part, number, timestamp_expression) %}
    dateadd({{ date_part }}, {{ number }}, {{ elementary.cast_as_timestamp(timestamp_expression) }})
{% endmacro %}

{% macro bigquery__timeadd(date_part, number, timestamp_expression) %}
    timestamp_add({{ elementary.cast_as_timestamp(timestamp_expression) }}, INTERVAL {{ number }} {{ date_part }})
{% endmacro %}

{% macro postgres__timeadd(date_part, number, timestamp_expression) %}
    {{ elementary.cast_as_timestamp(timestamp_expression) }} + {{ number }} * INTERVAL '1 {{ date_part }}'
{% endmacro %}

{% macro redshift__timeadd(date_part, number, timestamp_expression) %}
    dateadd({{ date_part }}, {{ number }}, {{ elementary.cast_as_timestamp(timestamp_expression) }})
{% endmacro %}