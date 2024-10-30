PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT TBL_PRIVILEGES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL GRANTEE    FORMAT A20 HEAD 'Grantee'
COL OWNER LIKE GRANTEE    HEAD 'Owner'
COL TABLE_NAME FORMAT A40 HEAD 'Table'
COL PRIVILEGE  FORMAT A20 HEAD 'Privilege'

SELECT grantee, owner, table_name, privilege
FROM user_tab_privs
WHERE grantee = USER
AND table_name LIKE 'DBMS%'
ORDER BY 1,2
/
