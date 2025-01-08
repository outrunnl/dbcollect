PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT AWR ERRORS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE COUNT LABEL "Total" OF SNAP_ID ON REPORT

COL DBID               FORMAT 9999999999
COL INSTANCE_NUMBER    FORMAT 99         HEAD 'Instnum'
COL TABLE_NAME         FORMAT A40        HEAD 'Table'
COL ERROR_NUMBER       FORMAT 9999999999 HEAD 'Error Number'
COL STEP_ID            FORMAT 99999      HEAD 'StepID'

SELECT dbid
, snap_id
, instance_number
, table_name
, error_number
FROM dba_hist_snap_error
ORDER BY 2,1
/

CLEAR COLUMNS
