CREATE TABLE public.documents (
  pk_documents SERIAL8,
  doc_stuff    TEXT,
  CONSTRAINT idx_documents PRIMARY KEY (pk_documents)
);
CREATE TABLE public.docs_usage (
  pk_docs_usage      SERIAL8,
  fk_documents       BIGINT,
  fk_library_profile BIGINT,
  place_used         TEXT,
  usage_json         JSON,
  CONSTRAINT idx_docs_usage PRIMARY KEY (pk_docs_usage)
);
CREATE TABLE public.library_profile (
  pk_library_profile SERIAL8,
  library_name       TEXT,
  CONSTRAINT idx_library_profile PRIMARY KEY (pk_library_profile)
);

CREATE INDEX es_documents ON documents USING zombodb ((documents.*));
CREATE INDEX es_docs_usage ON docs_usage USING zombodb ((docs_usage.*));
CREATE INDEX es_library_profile ON library_profile USING zombodb ((library_profile.*));

CREATE FUNCTION documents_shadow(anyelement) RETURNS anyelement IMMUTABLE STRICT PARALLEL SAFE LANGUAGE c AS '$libdir/zombodb.so', 'shadow_wrapper';
CREATE INDEX idxdocuments_master_view_shadow ON documents USING zombodb (documents_shadow(documents.*))
    WITH (
        shadow = true,
        options = $$
            usage_data:(pk_documents=<public.docs_usage.es_docs_usage>fk_documents),
            fk_library_profile=<public.library_profile.es_library_profile>pk_library_profile
        $$
    );

CREATE OR REPLACE VIEW documents_master_view AS
  SELECT
    documents.*,
    (SELECT json_agg(row_to_json(du.*)) AS json_agg
     FROM (SELECT
             docs_usage.*,
             (SELECT library_profile.library_name
              FROM library_profile
              WHERE library_profile.pk_library_profile = docs_usage.fk_library_profile) AS library_name
           FROM docs_usage
           WHERE documents.pk_documents = docs_usage.fk_documents) du) AS usage_data,
                 documents_shadow(documents) AS zdb
  FROM public.documents;

INSERT INTO documents (doc_stuff)
VALUES ('Every good boy does fine.'), ('Sally sells sea shells down by the seashore.'),
  ('The quick brown fox jumps over the lazy dog.');
INSERT INTO library_profile (library_name) VALUES ('GSO Public Library'), ('Library of Congress'), ('The interwebs.');
INSERT INTO docs_usage (fk_documents, fk_library_profile, place_used, usage_json)
VALUES (1, 1, 'somewhere', '{"title": "one one"}'), (2, 2, 'anywhere', '{"title": "two two"}'), (3, 3, 'everywhere', '{"title": "three three"}'), (3, 1, 'somewhere', '{"title": "three one"}');

SELECT count(*) FROM documents_master_view WHERE public.documents_master_view.zdb ==> 'somewhere';
SELECT count(*) FROM documents_master_view WHERE public.documents_master_view.zdb ==> 'GSO';

set enable_indexscan to off;
set enable_bitmapscan to off;
explain (costs off) SELECT count(*) FROM documents_master_view WHERE public.documents_master_view.zdb ==> 'somewhere';
SELECT count(*) FROM documents_master_view WHERE public.documents_master_view.zdb ==> 'somewhere';

select zdb.field_mapping('documents_master_view', 'doc_stuff');

select zdb.field_mapping('documents_master_view', 'usage_data');

select zdb.field_mapping('documents_master_view', 'usage_data.usage_json');

select zdb.field_mapping('documents_master_view', 'usage_json');

DROP TABLE documents CASCADE;
DROP TABLE docs_usage CASCADE;
DROP TABLE library_profile CASCADE;
DROP FUNCTION documents_shadow CASCADE;