CREATE OR REPLACE FUNCTION zdb.get_search_analyzer(index regclass, field text) RETURNS text
    IMMUTABLE STRICT PARALLEL SAFE
    LANGUAGE sql AS
$$
WITH properties AS (
    SELECT zdb.index_mapping(index) -> zdb.index_name(index) -> 'mappings' -> 'properties' ->
           field AS props)
SELECT COALESCE(props ->> 'search_analyzer', props ->> 'analyzer', 'standard')
FROM properties
LIMIT 1;

$$;

CREATE OR REPLACE FUNCTION zdb.get_index_analyzer(index regclass, field text) RETURNS text
    IMMUTABLE STRICT PARALLEL SAFE
    LANGUAGE sql AS
$$
WITH properties AS (
    SELECT zdb.index_mapping(index) -> zdb.index_name(index) -> 'mappings' -> 'properties' ->
           field AS props)
SELECT COALESCE(props ->> 'index_analyzer', props ->> 'analyzer', 'standard')
FROM properties
LIMIT 1;

$$;

CREATE OR REPLACE FUNCTION zdb.get_highlight_analysis_info(index_name regclass, field text)
    RETURNS TABLE
            (
                type             text,
                normalizer       text,
                index_tokenizer  text,
                search_tokenizer text
            )
    LANGUAGE sql
AS
$$
WITH mapping AS (SELECT jsonb_extract_path(
                                zdb.index_mapping(index_name),
                                VARIADIC ARRAY [zdb.index_name(index_name), 'mappings', 'properties'] ||
                                         string_to_array(replace(field, '.', '.properties.'), '.')) AS mapping)
SELECT mapping ->> 'type'                                        AS type,
       mapping ->> 'normalizer'                                  AS normalizer,
       mapping ->> 'analyzer'        AS index_analyzer,
       mapping ->> 'search_analyzer' AS search_analyzer
FROM mapping;
$$;

CREATE OR REPLACE FUNCTION zdb.get_null_copy_to_fields(index regclass) RETURNS TABLE(field_name text, mapping jsonb)
    IMMUTABLE STRICT PARALLEL SAFE
    LANGUAGE sql AS
$$
WITH field_mapping AS (
    with properties as (
        select zdb.index_mapping(index) -> zdb.index_name(index) -> 'mappings' -> 'properties' as properties
    )
    SELECT key, properties.properties -> key as mapping
    FROM (
             SELECT jsonb_object_keys(properties.properties) as key
             FROM properties
         ) x,
         properties
)
SELECT *
FROM field_mapping
WHERE mapping ->> 'type' = 'text'
  and mapping ->> 'copy_to' is null
$$;

CREATE FUNCTION zdb.version() RETURNS TABLE (schema_version text, internal_version text) LANGUAGE sql AS $$
SELECT zdb.schema_version(), zdb.internal_version();
$$;

