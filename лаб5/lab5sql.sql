--создаем спец таблицу
create table public."spec"
(
    id           integer not null,
    "table_name" varchar not null,
    "col_name"   varchar not null,
    "max_value"  integer not null
);
INSERT INTO SPEC
VALUES (1, 'spec', 'id', 1);
--создаем функцию для генерации имени триггера
CREATE OR REPLACE FUNCTION createTriggerName(t_name VARCHAR, c_name VARCHAR)
	RETURNS VARCHAR LANGUAGE plpgsql
AS $$
DECLARE
	tmpName varchar;
BEGIN
	tmpName = quote_ident(concat(t_name,'_',c_name,'_',(SELECT count(*)+1 FROM information_schema.triggers WHERE event_object_table=t_name)));
	WHILE EXISTS(SELECT * FROM information_schema.triggers AS trg WHERE trg.trigger_name = tmpName) LOOP
		tmpName = quote_ident(concat(t_name,'_',c_name,'_',gen_random_uuid()));
	END LOOP;
	RETURN tmpName;
END
$$;

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
    --пороверки
    If (NOT EXISTS(SELECT * FROM information_schema.tables WHERE table_name = t_name)) THEN
		RAISE EXCEPTION 'Таблицы % не существует!', t_name USING HINT = 'В начале нужно создать таблицу!';
	END IF;

    IF (NOT EXISTS(SELECT * FROM information_schema.columns
		WHERE table_name = t_name AND column_name = col)) THEN
		RAISE EXCEPTION 'Столбца % не существует!',col USING HINT = 'Столбец в таблице уже должен быть создан';
	END IF;

    IF (NOT EXISTS(SELECT * FROM information_schema.columns
				   WHERE table_name = t_name AND column_name = col
				   AND data_type='integer')) THEN
		RAISE EXCEPTION 'Неверный тип данных у столбца!' USING HINT = 'столбец должен быть integer!';
	END IF;
    --
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
        TInsert=createTriggerName(t_name,col);

        EXECUTE format('CREATE OR REPLACE TRIGGER %s AFTER INSERT
                        ON %I REFERENCING NEW TABLE AS NEW FOR EACH STATEMENT
                        EXECUTE FUNCTION tgFuncUpdateInsert(%I,%I)',TInsert,t_name,sp_id,col);
        TUpdate=createTriggerName(t_name,col);
        EXECUTE format('CREATE OR REPLACE TRIGGER %s AFTER UPDATE
                        ON %I REFERENCING NEW TABLE AS NEW FOR EACH STATEMENT
                        EXECUTE FUNCTION tgFuncUpdateInsert(%I,%I)',TUpdate,t_name,sp_id,col);
    end if;
        RETURN cur_max;
END;
$$;

--Тест 1
create table public.test
(
    id integer
);
INSERT INTO test
VALUES (10);

SELECT maxfunc('testNOT','id');
--Тест 2
SELECT maxfunc('test','lol');

--Тест 3
create table public.test2
(
    id varchar
);
SELECT maxfunc('test2','id');

--Тест 4

SELECT maxfunc('test','id');
SELECT * FROM information_schema.triggers;

--Тест 5
SELECT maxfunc('test','id');
SELECT * FROM information_schema.triggers;
--Тест 6
DROP TRIGGER test_id_1 ON test;
DELETE
FROM public.spec
WHERE id = 2;
SELECT maxfunc('test','id');
SELECT * FROM information_schema.triggers;

DROP TABLE test;
DROP TABLE test2;
DROP TABLE spec;
DROP FUNCTION tgFuncUpdateInsert;
DROP FUNCTION maxfunc;
DROP FUNCTION createTriggerName;

