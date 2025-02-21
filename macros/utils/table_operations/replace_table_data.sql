{% macro replace_table_data(relation, rows) %}
    {{ return(adapter.dispatch('replace_table_data', 'elementary')(relation, rows)) }}
{% endmacro %}

{# Default (Bigquery) - upload data to a temp table, and then atomically replace the table with a new one #}
{% macro default__replace_table_data(relation, rows) %}
    {% set intermediate_relation = elementary.create_intermediate_relation(relation, rows, temporary=True) %}
    {% do dbt.run_query(dbt.create_table_as(False, relation, 'select * from {}'.format(intermediate_relation))) %}
{% endmacro %}

{# Spark / Databricks - like BQ but without a temp table because they do not seem to work well #}
{% macro spark__replace_table_data(relation, rows) %}
    {% set intermediate_relation = elementary.create_intermediate_relation(relation, rows, temporary=False) %}
    {% do dbt.run_query(dbt.create_table_as(False, relation, 'select * from {}'.format(intermediate_relation))) %}
    {% do adapter.drop_relation(intermediate_relation) %}
{% endmacro %}

{# In Snowflake we can swap two tables atomically, so we can provide a faster implementation #}
{% macro snowflake__replace_table_data(relation, rows) %}
    {% set intermediate_relation = elementary.create_intermediate_relation(relation, rows, temporary=False) %}
    {% do dbt.run_query("alter table {} swap with {}".format(relation, intermediate_relation)) %}
    {% do adapter.drop_relation(intermediate_relation) %}
{% endmacro %}

{# In Postgres / Redshift we do not want to replace the table, because that will cause views without
   late binding to be deleted. So instead we atomically replace the data in a transaction #}
{% macro postgres__replace_table_data(relation, rows) %}
    {% set intermediate_relation = elementary.create_intermediate_relation(relation, rows, temporary=True) %}

    {% set query %}
        begin transaction;
        delete from {{ relation }};   -- truncate supported in Redshift transactions, but causes an immediate commit
        insert into {{ relation }} select * from {{ intermediate_relation }};
        commit;
    {% endset %}
    {% do dbt.run_query(query) %}
{% endmacro %}

{% macro create_intermediate_relation(base_relation, rows, temporary) %}
    {% if temporary %}
        {% set int_relation = dbt.make_temp_relation(base_relation) %}
    {% else %}
        {# for non temporary relations - make sure the name is unique #}
        {% set int_suffix = modules.datetime.datetime.utcnow().strftime('__tmp_%Y%m%d%H%M%S%f') %}
        {% set int_relation = dbt.make_temp_relation(base_relation, suffix=int_suffix).incorporate(type='table') %}
    {% endif %}

    {% do elementary.create_table_like(int_relation, base_relation, temporary=temporary) %}
    {% do elementary.insert_rows(int_relation, rows, should_commit, elementary.get_config_var('dbt_artifacts_chunk_size')) %}

    {% do return(int_relation) %}
{% endmacro %}
