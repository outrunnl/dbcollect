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

class TimeoutError(CustomException):
    pass

class InstanceDown(CustomException):
    pass

class DBCollectError(CustomException):
    pass
