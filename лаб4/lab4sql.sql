create table public."spec"
(
    id           integer not null,
    "table_name" varchar not null,
    "col_name"   varchar not null,
    "max_value"  integer not null
);
INSERT INTO SPEC
VALUES (1, 'spec', 'id', 1);

--создание функции триггеров
CREATE OR REPLACE FUNCTION tgFuncUpdateInsert()
	RETURNS trigger LANGUAGE plpgsql
AS
$$
BEGIN
	EXECUTE format('UPDATE spec SET max_value=(SELECT MAX(%s) FROM NEW)
        WHERE spec.id=%s AND max_value<(SELECT MAX(%s) FROM NEW)',tg_argv[1],tg_argv[0],tg_argv[1]);
	RETURN NEW;
END
$$;
--создание ХП
CREATE OR REPLACE FUNCTION maxfunc(t_name varchar, col varchar)
    RETURNS integer
    LANGUAGE plpgsql AS
$$
DECLARE
    cur_max integer;
    sp_id   integer;
    TInsert varchar;
    TUpdate varchar;
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
        TInsert=quote_ident(concat(t_name,'_',col,'_Insert'));
		TUpdate=quote_ident(concat(t_name,'_',col,'_Update'));


        EXECUTE format('CREATE OR REPLACE TRIGGER %s AFTER INSERT
                        ON %I REFERENCING NEW TABLE AS NEW FOR EACH STATEMENT
                        EXECUTE FUNCTION tgFuncUpdateInsert(%I,%I)',TInsert,t_name,sp_id,col);

        EXECUTE format('CREATE OR REPLACE TRIGGER %s AFTER UPDATE
                        ON %I REFERENCING NEW TABLE AS NEW FOR EACH STATEMENT
                        EXECUTE FUNCTION tgFuncUpdateInsert(%I,%I)',TUpdate,t_name,sp_id,col);
    end if;
        RETURN cur_max;
END;
$$;


create table public.test
(
    id integer
);
INSERT INTO test
VALUES (10);
SELECT maxfunc('test','id');

--Тест 1
UPDATE public.test
SET id = 15
WHERE id = 10
  AND ctid = '(0,1)';

--Тест 2
UPDATE public.test
SET id = 5
WHERE id = 15
  AND ctid = '(0,2)';

--Тест 3
INSERT INTO public.test (id)
VALUES (30);

--Тест 4
INSERT INTO public.test (id)
VALUES (17);

--Тест 5
truncate  test;

--Тест 6
SELECT maxfunc('test','id');

DROP TABLE test;
DROP TABLE spec;
DROP FUNCTION tgFuncUpdateInsert;
DROP FUNCTION maxfunc;

--тестировал добавление триггера
DROP  TRIGGER myT ON test;
CREATE OR REPLACE TRIGGER myT AFTER UPDATE
    ON test REFERENCING NEW TABLE AS NEW FOR EACH STATEMENT
    EXECUTE FUNCTION tgFuncUpdateInsert('2','id')