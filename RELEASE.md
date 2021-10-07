# DBCollect Release Notes

## 2.8.6
2021-10-07

* Changed so that dbcollect will call itself again as different user when dropping privileges
* Redesigned the instance detection method to be more robust, pick the right ORACLE_HOME based on timestamps
