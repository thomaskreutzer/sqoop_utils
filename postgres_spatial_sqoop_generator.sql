DO $$
DECLARE
   table_name text := 'your_src_tbl;
   table_schema text := 'your_src_db';
   hive_db text := 'your_target_db';
   rec RECORD;
   query text;
   n INTEGER;
   s text := 'sqoop import --connect ''jdbc:postgresql://yourhost.com/yourdb'' --username youruser--password yourpasswrod --query "SELECT ';
   splt_on text :='';
   fsplit integer=0;
   mch text :=' --map-column-hive ';
   mcj text :=' --map-column-java ';
   crt text := 'CREATE EXTERNAL TABLE IF NOT EXISTS ' || hive_db || '.' || table_name || '(';
BEGIN
   query := 'SELECT column_name, data_type FROM information_schema.columns WHERE table_schema=''' ;
   query := query || table_schema;
   query := query || ''' AND table_name=''' || table_name;
   query := query || ''' ORDER BY ordinal_position';
   --RAISE NOTICE '%', query;
   FOR rec IN EXECUTE query USING n
   LOOP
      --Take the first numeric column for the split by...
         IF rec.data_type = 'USER-DEFINED' THEN
           s := s || ' st_astext(' || rec.column_name || ') AS ' || rec.column_name || ',';
              mcj := mcj || rec.column_name || '=String ';
              crt := crt || rec.column_name || ' string,';
         ELSEIF rec.data_type = 'integer' THEN
           IF fsplit = 0 THEN
                fsplit := 1;
                splt_on := ' --split-by ' || rec.column_name || ' ';
              END IF;
              mch := mch || rec.column_name || '=Integer,';
              s := s || ' ' || rec.column_name || ',';
              crt := crt || rec.column_name || ' int,';
         ELSEIF rec.data_type = 'double precision' THEN
              mch := mch || rec.column_name || '=Double,';
              s := s || ' ' || rec.column_name || ',';
              crt := crt || rec.column_name || ' double,';
         ELSEIF rec.data_type = 'numeric' THEN
              mch := mch || rec.column_name || '=Decimal,';
              s := s || ' ' || rec.column_name || ',';
              crt := crt || rec.column_name || ' decimal,';
         ELSEIF rec.data_type = 'character varying' THEN
              mch := mch || rec.column_name || '=String,';
              s := s || ' ' || rec.column_name || ',';
              crt := crt || rec.column_name || ' string,';
         END IF;
      RAISE NOTICE '% - %', rec.column_name, rec.data_type;
   END LOOP;
   crt := TRIM(TRAILING ',' FROM crt);
   crt := crt || ') STORED AS ORC; ';
   mch := TRIM(TRAILING ',' FROM mch);
   s := TRIM(TRAILING ',' FROM s) || ' FROM ' || table_schema || '.\"' || table_name || '\" WHERE \$CONDITIONS"';
   s := s || ' --num-mappers 1' || splt_on;
   s := s || ' --hcatalog-table ' || table_name || ' --hcatalog-database ' || hive_db || ' --hcatalog-storage-stanza "stored as orcfile" ';
   s := s || mch;
   s := s || mcj;
   s := s || '&>  sqoop_' || table_name || '.out&';
   RAISE NOTICE '%', crt;
   RAISE NOTICE '%', s;
END $$;