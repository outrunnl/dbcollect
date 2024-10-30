-----------------------------------------------------------------------------
-- Title       : create_user.sql
-- Description : Create a low-privilege user for dbcollect
-- Author      : Bart Sjerps <bart@dirty-cache.com>
-- License     : GPLv3+
-----------------------------------------------------------------------------
-- This creates a dedicated user for running dbcollect.
-- Consider using the DBSNMP user instead:
-- DBSNMP has correct privileges by default (but
-- needs to be unlocked and have a valid password)

-- 12c+ only - this allows users to be created on the CDB
ALTER SESSION SET "_ORACLE_SCRIPT"=true;

-- Change the password to something more obscure
CREATE USER dbcollect IDENTIFIED BY _secret_;
GRANT CREATE SESSION TO dbcollect;
GRANT SELECT ANY DICTIONARY TO dbcollect;
GRANT EXECUTE ON dbms_workload_repository TO dbcollect;
