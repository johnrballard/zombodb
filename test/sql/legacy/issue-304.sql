CREATE TABLE issue304 (
  id serial8 not null primary key,
  data json
);

CREATE INDEX idxissue304 ON issue304 USING zombodb ( (issue304.*) );
INSERT INTO issue304 (data) VALUES ('[{"tags":["a", "b"], "text":"test"}]');

SELECT id FROM issue304 WHERE issue304 ==> 'not data.tags:a WITH data.text:test';

DROP TABLE issue304 CASCADE ;