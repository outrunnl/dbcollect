-----------------------------------------------------------------------------
-- Title       : update_feature_usage.sql
-- Description : Update the feature usage statistics
-- Author      : Bart Sjerps <bart@dirty-cache.com>
-- License     : GPLv3+
-----------------------------------------------------------------------------
-- This may prevent [DBC-E021] No AWR or Statspack detected

EXEC dbms_feature_usage_internal.exec_db_usage_sampling(sysdate);
