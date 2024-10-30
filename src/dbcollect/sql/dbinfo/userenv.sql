PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT USERENV
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- WORK IN PROGRESS

COL AUTHENTICATED_IDENTITY FORMAT A10
COL AUTHENTICATION_METHOD  FORMAT A10
COL IDENTIFICATION_TYPE    FORMAT A10
COL HOST                   FORMAT A10
COL ORACLE_HOME            FORMAT A60
COL OS_USER                FORMAT A10
COL ISDBA                  FORMAT A6
COL SERVER_HOST            FORMAT A10
COL SERVICE_NAME           FORMAT A10
COL TERMINAL               FORMAT A10
COL DATABASE_ROLE          FORMAT A16
COL DB_NAME                FORMAT A10
COL DB_DOMAIN              FORMAT A10
COL CDB_NAME               FORMAT A10


SELECT sys_context('USERENV','AUTHENTICATED_IDENTITY') AUTHENTICATED_IDENTITY
, sys_context('USERENV','AUTHENTICATION_METHOD')       AUTHENTICATION_METHOD
, sys_context('USERENV','IDENTIFICATION_TYPE')         IDENTIFICATION_TYPE
, sys_context('USERENV','HOST')          HOST
, sys_context('USERENV','ORACLE_HOME')   ORACLE_HOME
, sys_context('USERENV','OS_USER')       OS_USER
, sys_context('USERENV','ISDBA')         ISDBA
, sys_context('USERENV','SERVER_HOST')   SERVER_HOST
, sys_context('USERENV','SERVICE_NAME')  SERVICE_NAME
, sys_context('USERENV','TERMINAL')      TERMINAL
, sys_context('USERENV','DATABASE_ROLE') DATABASE_ROLE
, sys_context('USERENV','DB_NAME')       DB_NAME
, sys_context('USERENV','DB_DOMAIN')     DB_DOMAIN
, sys_context('USERENV','CDB_NAME')      CDB_NAME
FROM dual;