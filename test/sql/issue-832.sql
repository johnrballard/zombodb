CREATE SCHEMA adw;

CREATE TABLE adw.documents (
                               pk_doc_id bigint NOT NULL,
                               doc_file_name character varying
);

CREATE INDEX es_idx_adw_documents ON adw.documents
    USING zombodb ((documents.*))
    WITH (
    max_analyze_token_count='10000000',
    max_terms_count='2147483647');


CREATE TABLE adw.scope (
                           pk_scp bigint NOT NULL,
                           fk_scp_to_doc bigint,
                           name text,
                           scp_review_data json
);

CREATE INDEX es_idx_adw_scope ON adw.scope
    USING zombodb ((scope.*))
    WITH (
    max_analyze_token_count='10000000',
    max_terms_count='2147483647'
    );

CREATE FUNCTION adw.zdb_adw_documents_to_scope(anyelement) RETURNS anyelement
    LANGUAGE c IMMUTABLE STRICT
AS '$libdir/zombodb.so', 'shadow_wrapper';

CREATE FUNCTION adw.zdb_adw_scope_to_documents(anyelement) RETURNS anyelement
    LANGUAGE c IMMUTABLE STRICT
AS '$libdir/zombodb.so', 'shadow_wrapper';


CREATE INDEX es_idx_documents_to_scope_shadow ON adw.documents
    USING zombodb (adw.zdb_adw_documents_to_scope(documents.*))
    WITH (shadow='true',
    options='pk_doc_id=<adw.scope.es_idx_adw_scope>fk_scp_to_doc',

    max_analyze_token_count='10000000',
    max_terms_count='2147483647');

CREATE INDEX es_idx_scope_to_documents_shadow ON adw.scope
    USING zombodb (adw.zdb_adw_scope_to_documents(scope.*))
    WITH (shadow='true',
    options='fk_scp_to_doc=<adw.documents.es_idx_adw_documents>pk_doc_id',
--    options='fk_scp_to_doc=<adw.documents.es_idx_adw_documents>pk_doc_id, pk_doc_id = <adw.scope.es_idx_adw_scope>fk_scp_to_doc',
    max_analyze_token_count='10000000',
    max_terms_count='2147483647');


CREATE VIEW adw.scope_view AS
SELECT scope.pk_scp,
       documents.doc_file_name,
       scope.fk_scp_to_doc,
       scope.scp_review_data,
       adw.zdb_adw_scope_to_documents(scope.*) AS zdb
FROM (adw.scope
    JOIN adw.documents ON ((scope.fk_scp_to_doc = documents.pk_doc_id))
         );

INSERT INTO adw.documents values (10,'filenameA');
INSERT INTO adw.documents values (20,'filenameB');
INSERT INTO adw.documents values (30,'filenameC');
INSERT INTO adw.documents values (40,'filenameD');

INSERT INTO adw.scope values (100, 10, 'brandy', '[{"choice":"rock"},{"bucket":"sand"}]');
INSERT INTO adw.scope values (200, 20, 'sally', '[{"choice":"paper"},{"waves":"popemobile"}]');
INSERT INTO adw.scope values (300, 30, 'anchovy', '[{"choice":"scissors"},{"vehicle":"hydrant"}]');
INSERT INTO adw.scope values (400, 40, 'cupid', '[{"choice":"lizard"},{"silica gel":"inedible"}]');

select * from adw.scope_view order by pk_scp;
select * from zdb.tally('adw.scope_view','doc_file_name',True,'^.*','pk_scp:[100,300]') limit 10;
select * from zdb.tally('adw.scope_view','scp_review_data.choice',True,'^.*','') limit 10;
select * from zdb.dump_query('adw.scope_view', 'scp_review_data.choice:lizard');
select * from zdb.debug_query('adw.scope_view', 'scp_review_data.choice:lizard');
select * from adw.scope_view where scope_view.zdb ==> 'scp_review_data.choice:lizard' order by pk_scp;
select * from zdb.tally('adw.scope_view','doc_file_name',True,'^.*','scp_review_data.choice:lizard') limit 10;
select * from zdb.tally('adw.scope_view','doc_file_name',True,'^.*','name:brandy') limit 10;
select * from zdb.tally('adw.scope_view','doc_file_name',True,'^.*','name:cupid') limit 10;

DROP SCHEMA adw CASCADE;