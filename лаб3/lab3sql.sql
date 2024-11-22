create table public."spec"
(
    id           integer not null,
    "table_name" varchar not null,
    "col_name"   varchar not null,
    "max_value"  integer not null
);

INSERT INTO SPEC
VALUES (1, 'spec', 'id', 1);

CREATE OR REPLACE FUNCTION maxfunc(t_name varchar, col varchar)
    RETURNS integer
    LANGUAGE plpgsql AS
$$
DECLARE
    cur_max integer;
    sp_id   integer;
BEGIN
    SELECT max_value + 1 INTO cur_max FROM spec WHERE table_name = t_name AND col_name = col;
    if cur_max is not null
    THEN
        UPDATE spec SET max_value=max_value  + 1 WHERE table_name = t_name AND col_name = col returning max_value into cur_max;
    ELSE
        EXECUTE format('SELECT MAX(%I)+1 FROM %I', col, t_name) INTO cur_max;
        sp_id = maxfunc('spec', 'id');
        if cur_max is null
        THEN
            cur_max = 1;
        END if;
        INSERT INTO spec VALUES (sp_id, t_name, col, cur_max);
    end if;
        RETURN cur_max;
END;
$$;

SELECT maxfunc('spec', 'id');
SELECT *
FROM spec;

SELECT maxfunc('spec', 'id');
SELECT *
FROM spec;

create table public.test
(
    id integer
);
INSERT INTO test
VALUES (10);
SELECT maxfunc('test', 'id');
SELECT *
FROM spec;

SELECT maxfunc('test', 'id');
SELECT *
FROM spec;

create table public.test2
(
    num_value1 integer,
    num_value2 integer
);

SELECT maxfunc('test2', 'num_value1');
SELECT *
FROM spec;

SELECT maxfunc('test2', 'num_value1');
SELECT *
FROM spec;

INSERT INTO test2
VALUES (2, 13);

SELECT maxfunc('test2', 'num_value2');
SELECT *
FROM spec;

SELECT maxfunc('test2', 'num_value1');
SELECT maxfunc('test2', 'num_value1');
SELECT maxfunc('test2', 'num_value1');
SELECT maxfunc('test2', 'num_value1');
SELECT maxfunc('test2', 'num_value1');

SELECT *
FROM spec;

DROP FUNCTION maxfunc(varchar, varchar);

DROP TABLE test;
DROP TABLE test2;
DROP TABLE spec;
