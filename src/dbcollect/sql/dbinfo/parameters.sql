PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT INIT PARAMETERS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Non-null/non-default init parameters

COL PARAMETER   FORMAT A40  HEAD 'Parameter'
COL MODIFIED    FORMAT A10  HEAD 'Modified'
COL VALUE       FORMAT A160 HEAD 'Value'
COL DESCRIPTION FORMAT A80  HEAD 'Description'

SELECT name parameter
, DECODE(ismodified,'FALSE','','SYSTEM_MOD','SYSTEM','MODIFIED','SESSION',ismodified) MODIFIED
, description
, value
FROM v$parameter
WHERE value IS NOT NULL
AND (isdefault = 'FALSE' OR ISMODIFIED != 'FALSE')
ORDER BY name
/

CLEAR COMPUTES COLUMNS
