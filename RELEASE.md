# DBCollect Release Notes

## 1.9.0
2022-01-27

* Added daily archiving summary (daily change rate - for sizing backup)
* Moved flashback log summary to its own section
* Minor improvements in the other reports

## 1.8.9
2022-01-01

* Updated the AWR generation script. It now ignores manual AWR snapshots and only picks up AWRs with snap_flag = 0 (scheduled AWR reports).

## 1.8.8
2021-12-16

* Fix issue where the update function could fail

## 1.8.7
2021-12-16

* Fix minor db instance parsing bug

## 1.8.6
2021-10-07

* Changed so that dbcollect will call itself again as different user when dropping privileges
* Redesigned the instance detection method to be more robust, pick the right ORACLE_HOME based on timestamps
