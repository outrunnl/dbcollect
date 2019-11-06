-----------------------------------------------------------------------------
-- Title       : update_feature_usager.sql
-- Description : Updates feature usage statistics
-----------------------------------------------------------------------------
EXEC DBMS_FEATURE_USAGE_INTERNAL.exec_db_usage_sampling(SYSDATE);
