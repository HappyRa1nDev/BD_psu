--создадим таблицу
CREATE TABLE test
(
    id integer,
    str varchar
);

INSERT INTO test(id,str) VALUES (1, 'v1'), (2, 'v2');

CREATE TABLE test2
(
    id integer
);
INSERT INTO test2(id) VALUES (1000), (5000);

CREATE OR REPLACE FUNCTION myTriggerFunc() RETURNS TRIGGER LANGUAGE plpgsql AS $$
    DECLARE
        columns refcursor;
        c_name varchar;
        columns_list varchar;
        type_tg varchar;
        _source_table varchar;
        clone_table varchar;
    BEGIN
        OPEN columns FOR SELECT column_name FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = tg_table_name ORDER BY ordinal_position;
        FETCH columns INTO c_name;
        columns_list = quote_ident(c_name);
        LOOP
            FETCH columns INTO c_name;
            IF NOT FOUND THEN EXIT; END IF;
            columns_list = columns_list || ',' || quote_ident(c_name);
        END LOOP;
        CLOSE columns;
        columns_list = columns_list || ',date,cur_user,type_tg';

        clone_table = tg_argv[0];
        if TG_OP = 'DELETE' THEN
            _source_table = 'old_table';
            type_tg = 'delete';
        ELSE
            _source_table = 'new_table';
            if TG_OP = 'UPDATE' THEN
                type_tg = 'update';
            ELSE
                type_tg = 'insert';
            END IF;
        END IF;

        EXECUTE format('INSERT INTO %s (%s) SELECT n.*, now(), user, ''%s'' FROM %s n',
            clone_table, columns_list, type_tg, _source_table);
        RETURN NULL;
    END;
$$;

CREATE OR REPLACE FUNCTION createCloneTable(t_name varchar)
    RETURNS boolean LANGUAGE plpgsql AS
$$
    DECLARE
        clone_name varchar;
    BEGIN
       clone_name=quote_ident(concat(t_name,'_clone'));
       EXECUTE format('CREATE TABLE %s AS TABLE %s',clone_name,t_name);

        -- добавляем столбцы
        EXECUTE format('ALTER TABLE %s
            ADD COLUMN date timestamp without time zone', clone_name);
        EXECUTE format('ALTER TABLE %s
            ADD COLUMN cur_user character varying(50)', clone_name);
        EXECUTE format('ALTER TABLE %s
            ADD COLUMN type_tg character varying(50)', clone_name);

        EXECUTE format(
            'CREATE TRIGGER %s AFTER INSERT ON %s REFERENCING NEW TABLE AS new_table FOR EACH STATEMENT EXECUTE PROCEDURE myTriggerFunc(%L)',
            quote_ident(t_name || '_insert'), t_name, clone_name);
        EXECUTE format(
            'CREATE TRIGGER %s AFTER UPDATE ON %s REFERENCING OLD TABLE AS old_table NEW TABLE AS new_table FOR EACH STATEMENT EXECUTE PROCEDURE myTriggerFunc(%L)',
            quote_ident(t_name || '_update'), t_name, clone_name);
        EXECUTE format(
            'CREATE TRIGGER %s AFTER DELETE ON %s REFERENCING OLD TABLE AS old_table FOR EACH STATEMENT EXECUTE PROCEDURE myTriggerFunc(%L)',
           quote_ident(t_name || '_delete'), t_name, clone_name);


        RETURN true;
    END
$$;

CREATE OR REPLACE FUNCTION createAllClones()
    RETURNS boolean LANGUAGE plpgsql AS
$$
    DECLARE
        _tables refcursor;
        _table_name varchar;
    BEGIN
        OPEN _tables FOR SELECT table_name FROM information_schema.tables
           WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
        LOOP
            FETCH _tables INTO _table_name;
            IF NOT FOUND THEN EXIT; END IF;
            PERFORM createCloneTable(_table_name);
        END LOOP;
        CLOSE _tables;
        RETURN true;
    END;
$$;

SELECT createAllClones();

INSERT INTO public.test (id, str)
VALUES (5, 'V5');

UPDATE public.test
SET str = 'LLLL'
WHERE id = 2;

delete FROM test where id =2;

DROP TABLE test2;
DROP TABLE test;