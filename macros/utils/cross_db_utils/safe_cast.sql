{% macro safe_cast(field, type) %}
    {{ return(adapter.dispatch('safe_cast', 'elementary') (field, type)) }}
{% endmacro %}

{% macro default__safe_cast(field, type) %}
    {% set macro = dbt.safe_cast or dbt_utils.safe_cast %}
    {% if not macro %}
        {{ exceptions.raise_compiler_error("Did not find a `safe_cast` macro.") }}
    {% endif %}
    {{ return(macro(field, type)) }}
{% endmacro %}

{% macro spark__safe_cast(field, type) %}
    try_cast({{field}} as {{type}})
{% endmacro %}
