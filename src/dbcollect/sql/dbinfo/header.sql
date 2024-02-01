SET colsep '|'
SET tab off feedback off verify off heading on lines 1000 pages 50000 trims on
ALTER SESSION SET nls_date_format='YYYY-MM-DD HH24:MI:SS';
ALTER SESSION SET nls_timestamp_format='YYYY-MM-DD HH24:MI:SS';
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';

WHENEVER SQLERROR EXIT SQL.SQLCODE

-- set emb on
