--
-- PG to ES type mapping support
--

--
-- filter/analyzer/mapping support
--

CREATE TABLE zdb.filters
(
    name       text                  NOT NULL PRIMARY KEY,
    definition jsonb                 NOT NULL,
    is_default boolean DEFAULT false NOT NULL
);

CREATE TABLE zdb.char_filters
(
    name       text                  NOT NULL PRIMARY KEY,
    definition jsonb                 NOT NULL,
    is_default boolean DEFAULT false NOT NULL
);

CREATE TABLE zdb.analyzers
(
    name       text                  NOT NULL PRIMARY KEY,
    definition jsonb                 NOT NULL,
    is_default boolean DEFAULT false NOT NULL
);

CREATE TABLE zdb.normalizers
(
    name       text                  NOT NULL PRIMARY KEY,
    definition jsonb                 NOT NULL,
    is_default boolean DEFAULT false NOT NULL
);

CREATE TABLE zdb.mappings
(
    table_name regclass NOT NULL,
    field_name text     NOT NULL,
    definition jsonb    NOT NULL,
    es_only    boolean  NOT NULL DEFAULT false,
    PRIMARY KEY (table_name, field_name)
);

CREATE TABLE zdb.type_mappings
(
    type_name  regtype               NOT NULL PRIMARY KEY,
    definition jsonb   DEFAULT NULL,
    is_default boolean DEFAULT false NOT NULL,
    funcid     regproc DEFAULT null
);

CREATE TABLE zdb.tokenizers
(
    name       text                  NOT NULL PRIMARY KEY,
    definition jsonb                 NOT NULL,
    is_default boolean DEFAULT false NOT NULL
);

CREATE TABLE zdb.type_conversions
(
    typeoid    regtype NOT NULL PRIMARY KEY,
    funcoid    regproc NOT NULL,
    is_default boolean DEFAULT false
);

CREATE TABLE zdb.similarities
(
    name       text NOT NULL PRIMARY KEY,
    definition jsonb
);

SELECT pg_catalog.pg_extension_config_dump('zdb.filters', 'WHERE NOT is_default');
SELECT pg_catalog.pg_extension_config_dump('zdb.char_filters', 'WHERE NOT is_default');
SELECT pg_catalog.pg_extension_config_dump('zdb.analyzers', 'WHERE NOT is_default');
SELECT pg_catalog.pg_extension_config_dump('zdb.normalizers', 'WHERE NOT is_default');
SELECT pg_catalog.pg_extension_config_dump('zdb.mappings', '');
SELECT pg_catalog.pg_extension_config_dump('zdb.tokenizers', 'WHERE NOT is_default');
SELECT pg_catalog.pg_extension_config_dump('zdb.type_mappings', 'WHERE NOT is_default');
SELECT pg_catalog.pg_extension_config_dump('zdb.type_conversions', 'WHERE NOT is_default');
SELECT pg_catalog.pg_extension_config_dump('zdb.similarities', '');


CREATE OR REPLACE FUNCTION zdb.define_filter(name text, definition json) RETURNS void
    LANGUAGE sql
    VOLATILE STRICT AS
$$
DELETE
FROM zdb.filters
WHERE name = $1;
INSERT INTO zdb.filters(name, definition)
VALUES ($1, $2);
$$;

CREATE OR REPLACE FUNCTION zdb.define_char_filter(name text, definition json) RETURNS void
    LANGUAGE sql
    VOLATILE STRICT AS
$$
DELETE
FROM zdb.char_filters
WHERE name = $1;
INSERT INTO zdb.char_filters(name, definition)
VALUES ($1, $2);
$$;

CREATE OR REPLACE FUNCTION zdb.define_analyzer(name text, definition json) RETURNS void
    LANGUAGE sql
    VOLATILE STRICT AS
$$
DELETE
FROM zdb.analyzers
WHERE name = $1;
INSERT INTO zdb.analyzers(name, definition)
VALUES ($1, $2);
$$;

CREATE OR REPLACE FUNCTION zdb.define_normalizer(name text, definition json) RETURNS void
    LANGUAGE sql
    VOLATILE STRICT AS
$$
DELETE
FROM zdb.normalizers
WHERE name = $1;
INSERT INTO zdb.normalizers(name, definition)
VALUES ($1, $2);
$$;

CREATE OR REPLACE FUNCTION zdb.define_field_mapping(table_name regclass, field_name text, definition json) RETURNS void
    LANGUAGE sql
    VOLATILE STRICT AS
$$
DELETE
FROM zdb.mappings
WHERE table_name = $1
  AND field_name = $2;
INSERT INTO zdb.mappings(table_name, field_name, definition)
VALUES ($1, $2, $3);
$$;

CREATE OR REPLACE FUNCTION zdb.define_es_only_field(table_name regclass, field_name text, definition json) RETURNS void
    LANGUAGE sql
    VOLATILE STRICT AS
$$
DELETE
FROM zdb.mappings
WHERE table_name = $1
  AND field_name = $2;
INSERT INTO zdb.mappings(table_name, field_name, definition, es_only)
VALUES ($1, $2, $3, true);
$$;

CREATE OR REPLACE FUNCTION zdb.define_type_mapping(type_name regtype, definition json) RETURNS void
    LANGUAGE sql
    VOLATILE STRICT AS
$$
DELETE
FROM zdb.type_mappings
WHERE type_name = $1;
INSERT INTO zdb.type_mappings(type_name, definition)
VALUES ($1, $2);
$$;

CREATE OR REPLACE FUNCTION zdb.define_type_mapping(type_name regtype, funcid regproc) RETURNS void
    LANGUAGE sql
    VOLATILE STRICT AS
$$
DELETE
FROM zdb.type_mappings
WHERE type_name = $1;
INSERT INTO zdb.type_mappings(type_name, funcid)
VALUES ($1, $2);
$$;

CREATE OR REPLACE FUNCTION zdb.define_tokenizer(name text, definition json) RETURNS void
    LANGUAGE sql
    VOLATILE STRICT AS
$$
DELETE
FROM zdb.tokenizers
WHERE name = $1;
INSERT INTO zdb.tokenizers(name, definition)
VALUES ($1, $2);
$$;

CREATE OR REPLACE FUNCTION zdb.define_similarity(name text, definition json) RETURNS void
    LANGUAGE sql
    VOLATILE STRICT AS
$$
    DELETE FROM zdb.similarities WHERE name = $1;
    INSERT INTO zdb.similarities(name, definition) VALUES ($1, $2);
$$;

INSERT INTO zdb.filters(name, definition, is_default)
VALUES ('zdb_truncate_to_fit', '{
  "type": "truncate",
  "length": 10922
}', true) ON CONFLICT (name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.filters(name, definition, is_default)
VALUES ('shingle_filter', '{
  "type": "shingle",
  "min_shingle_size": 2,
  "max_shingle_size": 2,
  "output_unigrams": true,
  "token_separator": "$"
}', true) ON CONFLICT (name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.filters(name, definition, is_default)
VALUES ('shingle_filter_search', '{
  "type": "shingle",
  "min_shingle_size": 2,
  "max_shingle_size": 2,
  "output_unigrams": false,
  "output_unigrams_if_no_shingles": true,
  "token_separator": "$"
}', true) ON CONFLICT (name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.normalizers(name, definition, is_default)
VALUES ('lowercase', '{
  "type": "custom",
  "char_filter": [],
  "filter": [
    "lowercase"
  ]
}', true) ON CONFLICT (name) DO UPDATE SET definition = excluded.definition;

-- same as 'lowercase' for backwards compatibility
INSERT INTO zdb.normalizers(name, definition, is_default)
VALUES ('exact', '{
  "type": "custom",
  "char_filter": [],
  "filter": [
    "lowercase"
  ]
}', true) ON CONFLICT (name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.analyzers(name, definition, is_default)
VALUES ('zdb_standard', '{
  "type": "standard",
  "filter": [
    "zdb_truncate_to_fit",
    "lowercase"
  ]
}', true) ON CONFLICT (name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.analyzers(name, definition, is_default)
VALUES ('zdb_all_analyzer', '{
  "type": "standard",
  "filter": [
    "zdb_truncate_to_fit",
    "lowercase"
  ]
}', true) ON CONFLICT (name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.analyzers(name, definition, is_default)
VALUES ('fulltext_with_shingles', '{
  "type": "custom",
  "tokenizer": "standard",
  "filter": [
    "lowercase",
    "shingle_filter",
    "zdb_truncate_to_fit"
  ]
}', true) ON CONFLICT (name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.analyzers(name, definition, is_default)
VALUES ('fulltext_with_shingles_search', '{
  "type": "custom",
  "tokenizer": "standard",
  "filter": [
    "lowercase",
    "shingle_filter_search"
  ]
}', true) ON CONFLICT (name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.analyzers(name, definition, is_default)
VALUES ('fulltext', '{
  "type": "standard",
  "filter": [
    "zdb_truncate_to_fit",
    "lowercase"
  ]
}', true) ON CONFLICT (name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.analyzers(name, definition, is_default)
VALUES ('phrase', '{
  "type": "standard",
  "copy_to": "zdb_all",
  "filter": [
    "zdb_truncate_to_fit",
    "lowercase"
  ]
}', true) ON CONFLICT (name) DO UPDATE SET definition = excluded.definition;


CREATE DOMAIN zdb.phrase AS text;
CREATE DOMAIN zdb.phrase_array AS text[];
CREATE DOMAIN zdb.fulltext AS text;
CREATE DOMAIN zdb.fulltext_with_shingles AS text;
CREATE DOMAIN zdb.zdb_standard AS text;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('"char"', '{
  "type": "keyword"
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('char', '{
  "type": "keyword",
  "copy_to": "zdb_all",
  "ignore_above": 10922,
  "normalizer": "lowercase"
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('bytea', '{
  "type": "binary"
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('boolean', '{
  "type": "boolean"
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('smallint', '{
  "type": "short"
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('integer', '{
  "type": "integer"
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('bigint', '{
  "type": "long"
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('real', '{
  "type": "float"
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('double precision', '{
  "type": "double"
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('character varying', '{
  "type": "keyword",
  "copy_to": "zdb_all",
  "ignore_above": 10922,
  "normalizer": "lowercase"
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('text', '{
  "type": "text",
  "copy_to": "zdb_all",
  "fielddata": true,
  "analyzer": "zdb_standard"
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

--INSERT INTO zdb.type_mappings(type_name, definition, is_default) VALUES (
--  'citext', '{
--    "type": "text",
--    "copy_to": "zdb_all",
--    "fielddata": true,
--    "analyzer": "zdb_standard"
--  }', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('time without time zone', '{
  "type": "keyword",
  "copy_to": "zdb_all",
  "fields": {
    "date": {
      "type": "date",
      "format": "HH:mm||HH:mm:ss||HH:mm:ss.S||HH:mm:ss.SS||HH:mm:ss.SSS||HH:mm:ss.SSSS||HH:mm:ss.SSSSS||HH:mm:ss.SSSSSS"
    }
  }
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('time with time zone', '{
  "type": "keyword",
  "copy_to": "zdb_all",
  "fields": {
    "date": {
      "type": "date",
      "format": "HH:mmX||HH:mm:ssX||HH:mm:ss.SX||HH:mm:ss.SSX||HH:mm:ss.SSSX||HH:mm:ss.SSSSX||HH:mm:ss.SSSSSX||HH:mm:ss.SSSSSSX"
    }
  }
}
', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('date', '{
  "type": "keyword",
  "copy_to": "zdb_all",
  "fields": {
    "date": {
      "type": "date"
    }
  }
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('timestamp without time zone', '{
  "type": "keyword",
  "copy_to": "zdb_all",
  "fields": {
    "date": {
      "type": "date"
    }
  }
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('timestamp with time zone', '{
  "type": "keyword",
  "copy_to": "zdb_all",
  "fields": {
    "date": {
      "type": "date"
    }
  }
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('json', '{
  "type": "nested",
  "include_in_parent": true
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('jsonb', '{
  "type": "nested",
  "include_in_parent": true
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('inet', '{
  "type": "ip",
  "copy_to": "zdb_all"
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('zdb.phrase', '{
  "type": "text",
  "copy_to": "zdb_all",
  "fielddata": true,
  "analyzer": "phrase"
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('zdb.phrase_array', '{
  "type": "text",
  "copy_to": "zdb_all",
  "fielddata": true,
  "analyzer": "phrase"
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('zdb.fulltext', '{
  "type": "text",
  "fielddata": true,
  "analyzer": "fulltext"
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('zdb.fulltext_with_shingles', '{
  "type": "text",
  "fielddata": true,
  "analyzer": "fulltext_with_shingles",
  "search_analyzer": "fulltext_with_shingles_search"
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('point', '{
  "type": "geo_point"
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('uuid', '{
  "type": "keyword",
  "copy_to": "zdb_all",
  "ignore_above": 10922,
  "normalizer": "lowercase"
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.type_mappings(type_name, definition, is_default)
VALUES ('tsvector', '{
  "type": "text",
  "copy_to": "zdb_all",
  "fielddata": true,
  "analyzer": "zdb_standard"
}', true) ON CONFLICT (type_name) DO UPDATE SET definition = excluded.definition;

CREATE DOMAIN zdb.arabic AS text;
CREATE DOMAIN zdb.armenian AS text;
CREATE DOMAIN zdb.basque AS text;
CREATE DOMAIN zdb.brazilian AS text;
CREATE DOMAIN zdb.bulgarian AS text;
CREATE DOMAIN zdb.catalan AS text;
CREATE DOMAIN zdb.chinese AS text;
CREATE DOMAIN zdb.cjk AS text;
CREATE DOMAIN zdb.czech AS text;
CREATE DOMAIN zdb.danish AS text;
CREATE DOMAIN zdb.dutch AS text;
CREATE DOMAIN zdb.english AS text;
CREATE DOMAIN zdb.fingerprint AS text;
CREATE DOMAIN zdb.finnish AS text;
CREATE DOMAIN zdb.french AS text;
CREATE DOMAIN zdb.galician AS text;
CREATE DOMAIN zdb.german AS text;
CREATE DOMAIN zdb.greek AS text;
CREATE DOMAIN zdb.hindi AS text;
CREATE DOMAIN zdb.hungarian AS text;
CREATE DOMAIN zdb.indonesian AS text;
CREATE DOMAIN zdb.irish AS text;
CREATE DOMAIN zdb.italian AS text;
CREATE DOMAIN zdb.keyword AS character varying;
CREATE DOMAIN zdb.latvian AS text;
CREATE DOMAIN zdb.norwegian AS text;
CREATE DOMAIN zdb.persian AS text;
CREATE DOMAIN zdb.portuguese AS text;
CREATE DOMAIN zdb.romanian AS text;
CREATE DOMAIN zdb.russian AS text;
CREATE DOMAIN zdb.sorani AS text;
CREATE DOMAIN zdb.spanish AS text;
CREATE DOMAIN zdb.simple AS text;
CREATE DOMAIN zdb.standard AS text;
CREATE DOMAIN zdb.swedish AS text;
CREATE DOMAIN zdb.turkish AS text;
CREATE DOMAIN zdb.thai AS text;
CREATE DOMAIN zdb.whitespace AS text;

--
-- emoji analyzer support
--

INSERT INTO zdb.tokenizers(name, definition, is_default)
VALUES ('emoji', '{
  "type": "pattern",
  "pattern": "([\\ud83c\\udf00-\\ud83d\\ude4f]|[\\ud83d\\ude80-\\ud83d\\udeff])",
  "group": 1
}', true) ON CONFLICT (name) DO UPDATE SET definition = excluded.definition;

INSERT INTO zdb.analyzers(name, definition, is_default)
VALUES ('emoji', '{
  "tokenizer": "emoji"
}', true) ON CONFLICT (name) DO UPDATE SET definition = excluded.definition;

CREATE OR REPLACE FUNCTION zdb.define_type_conversion(typeoid regtype, funcoid regproc) RETURNS void
    VOLATILE STRICT
    LANGUAGE sql AS
$$
DELETE
FROM zdb.type_conversions
WHERE typeoid = $1;
INSERT INTO zdb.type_conversions(typeoid, funcoid)
VALUES ($1, $2);
$$;


--
-- permissions to do all the things to the tables defined here
---

GRANT ALL ON zdb.analyzers TO PUBLIC;
GRANT ALL ON zdb.char_filters TO PUBLIC;
GRANT ALL ON zdb.filters TO PUBLIC;
GRANT ALL ON zdb.mappings TO PUBLIC;
GRANT ALL ON zdb.similarities TO PUBLIC;
GRANT ALL ON zdb.tokenizers TO PUBLIC;
GRANT ALL ON zdb.type_mappings TO PUBLIC;
GRANT ALL ON zdb.normalizers TO PUBLIC;
GRANT ALL ON zdb.type_conversions TO PUBLIC;
