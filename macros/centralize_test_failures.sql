{% macro centralize_test_failures(results) %}
  {%- set test_results = [] -%}

  {# Basic input check #}
  {% if results is none %}
    {{ log("No results provided to centralize_test_failures; skipping.", info=True) if execute }}
    {%- set results = [] -%}
  {% endif %}

  {# Collect relevant test results #}
  {%- for result in results -%}
    {%- if result.node.resource_type == 'test'
          and result.status != 'skipped'
          and (result.node.config.get('store_failures') or flags.STORE_FAILURES)
      -%}
      {%- do test_results.append(result) -%}
    {%- endif -%}
  {%- endfor -%}

  {%- set central_tbl = target.schema ~ '.test_failures' -%}
  {{ log("Centralizing test failures in " ~ central_tbl, info=True) if execute }}

  {% if test_results | length > 0 and execute %}
    {# Build the CREATE TABLE SQL #}
    {%- set parts = [] -%}
    {%- for result in test_results -%}
      {%- set sql_part -%}
        select
          '{{ result.node.name }}' as test_name,
          object_construct_keep_null(*) as failure_details,
          current_timestamp() as load_time
        from {{ result.node.relation_name }}
      {%- endset -%}
      {%- do parts.append(sql_part) -%}
    {%- endfor -%}

    {%- set create_sql = "create or replace table " ~ central_tbl ~ " as (" ~ parts | join(" union all ") ~ ")" -%}

    {# Execute the DDL #}
    {{ log("Executing DDL to create/replace " ~ central_tbl, info=True) }}
    {% do run_query(create_sql) %}
    {{ log("Successfully created/updated " ~ central_tbl, info=True) }}
  {% else %}
    {{ log("No test failures to centralize", info=True) if execute }}
  {% endif %}
{% endmacro %}