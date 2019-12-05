-----------------------------------------------------------------------------
-- Title       : update_feature_usage.sql
-- Description : Updates feature usage statistics
-----------------------------------------------------------------------------
-- If AWR snapshots are enabled but an AWR report has never been generated,
-- the feature_usage will show count 0 for feature 'AWR Report'.
-- To update, run an AWR report once, for example 
-- using @?/rdbms/admin/awrrpti
-- Afterwards, run this script to update the usage tables.
-- Only do this if you are licensed for Diagnostics and Tuning pack!

EXEC DBMS_FEATURE_USAGE_INTERNAL.exec_db_usage_sampling(SYSDATE);
