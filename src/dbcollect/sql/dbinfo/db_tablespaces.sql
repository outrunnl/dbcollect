PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT TABLESPACES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL PDB_NAME                 FORMAT A20     HEAD 'PDB'
COL TABLESPACE_NAME          FORMAT A25     HEAD 'Tablespace'
COL OBJECTS                  FORMAT 999,990 HEAD 'Objects'
COL FILES                    FORMAT 999,990 HEAD 'Files'
COL BLKSZ                    FORMAT 99      HEAD 'Blocksize'
COL STATUS                   FORMAT A9      HEAD 'Status'
COL CONTENTS                 FORMAT A9      HEAD 'Contents'
COL COMPRESSION              FORMAT A12     HEAD 'Compression'
COL BIGFILE                  FORMAT A7      HEAD 'Bigfile'
COL ENCRYPTED                FORMAT A9      HEAD 'Encrypted'
COL COMPRESS_FOR             FORMAT A12     HEAD 'Compress For'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF FILES ALLOCATED FREE_MB USED_MB OBJECTS ON REPORT

SELECT '-' pdb_name
, tablespace_name
, dt.block_size/1024 blksz
, status
, contents
, def_tab_compression compression
, bigfile
, encrypted
, compress_for
, objects
, files
FROM dba_tablespaces dt
LEFT JOIN (SELECT tablespace_name, count(*) objects FROM dba_segments   GROUP BY tablespace_name) USING (tablespace_name)
LEFT JOIN (SELECT tablespace_name, count(*) files   FROM dba_data_files GROUP BY tablespace_name) USING (tablespace_name)
ORDER BY contents, tablespace_name
/

CLEAR COMPUTES COLUMNS
