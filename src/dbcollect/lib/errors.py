"""
errors.py - Exception subclasses for DBCollect
Copyright (c) 2023 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

class CustomException(Exception):
    pass

class ZipCreateError(CustomException):
    pass

class ReportingError(CustomException):
    pass

class SQLPlusError(CustomException):
    pass

class Errors():
    """
    Info, Warning and Error messages
    """
    W001 = "[DBC-W001] Subprocess %s interrupted"
    W002 = "[DBC-W002] %s: No prior AWR usage detected, continuing anyway (--force-awr)"
    W003 = "[DBC-W003] Writing data to zip file failed: %s (%s)"
    W004 = "[DBC-W004] Skipping %s: No prior AWR usage or Statspack detected (--ignore)"
    W005 = "[DBC-W005] Executing %s failed (%s)"
    W006 = "[DBC-W006] Reading DMI info failed (%s)"

    E001 = "[DBC-E001] Unknown error: %s, see logfile for debug info"
    E002 = "[DBC-E002] Keyboard interrupt, Aborting..."
    E003 = "[DBC-E003] Cannot create zipfile %s"
    E004 = "[DBC-E004] OS error retrieving %s: %s"
    E005 = "[DBC-E005] IO error retrieving %s: %s"
    E006 = "[DBC-E006] HTML Parsing error in %s, not stripped"
    E007 = "[DBC-E007] I/O error writing %s: %s"
    E008 = "[DBC-E008] Unknown platform %s"
    E009 = "[DBC-E009] %s: Terminated (pid=%s, rc=%s) running SQLPlus script %s"
    E010 = "[DBC-E010] %s: Timeout (pid=%s, %s seconds) running SQLPlus script %s"
    E011 = "[DBC-E011] %s: Generator timeout (queue full, %s seconds)"
    E012 = "[DBC-E012] I/O error in %s: %s"
    E013 = "[DBC-E013] Exception in %s: %s"
    E014 = "[DBC-E014] Cannot create logfile %s (%s)"
    E015 = "[DBC-E015] Unknown error reading file %s (%s)"
    E016 = "[DBC-E016] oraInst.loc not found or readable"
    E017 = "[DBC-E017] inventory.xml not found or readable"
    E018 = "[DBC-E018] oratab not found or readable"
    E019 = "[DBC-E019] Failed to run SQLPlus (%s): %s"
    E020 = "[DBC-E020] Zipfile already exists: %s"
    E021 = "[DBC-E021] No AWR or Statspack detected for %s (try --force-awr or --ignore)"
    E022 = "[DBC-E022] Worker failed, rc=%s"
    E023 = "[DBC-E023] Job generator failed, rc=%s"
    E024 = "[DBC-E024] NMON directory not found: %s"
    E025 = "[DBC-E025] Not a valid NMON file: %s"
    E026 = "[DBC-E026] %s: Parsing instance info failed"
