PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT PDB DATABASE FILES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL PDB_NAME  FORMAT A20               HEAD 'PDB'
COL TS_NAME   FORMAT A25               HEAD 'Tablespace'
COL SIZE_MB   FORMAT 99,999,999,990.99 HEAD 'Size'
COL FILENAME  FORMAT A180              HEAD 'Filename'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB ON REPORT

SELECT P.NAME   PDB_NAME
, T.name        TS_NAME
, bytes/1048576 SIZE_MB
, filename
FROM (
    SELECT CON_ID
    , 'DATAFILE'        FILETYPE
    , ts#
    , bytes
    , D.block_size/1024 BLOCKSIZE
    , D.name            FILENAME
    FROM v$datafile D
    UNION ALL
    SELECT CON_ID
    , 'TEMPFILE'
    , ts#
    , bytes
    , D.block_size/1024
    , D.name
    FROM v$tempfile D) F
LEFT OUTER JOIN v$pdbs P USING (con_id)
LEFT OUTER JOIN v$tablespace T USING (con_id, ts#)
ORDER BY pdb_name NULLS FIRST, ts_name
/

CLEAR COMPUTES COLUMNS