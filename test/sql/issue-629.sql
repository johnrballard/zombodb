CREATE OR REPLACE FUNCTION issue629() RETURNS bool LANGUAGE plpgsql AS $$
DECLARE

BEGIN
    BEGIN
        select count(*)
        from so_posts
        where so_posts ==>
              '{ "function_score": { "query": { "match_all": {} }, "field_value_factor": { "field": "answer_countd" } } }';
    EXCEPTION WHEN others THEN
        RETURN true;
    END;

    RETURN false;
END;
$$;

SELECT issue629();
DROP FUNCTION issue629;