__author__    = "Bart Sjerps <bart@outrun.nl>"
__copyright__ = "Copyright 2020, Bart Sjerps"
__license__   = "GPLv3+"

"""
Logging setup for dbcollect
logsetup sets up dual logging via separate handlers, one is the dbcollect logfile
which logs at DEBUG level (most everything)
the other is the consolehandler which logs at INFO or ERROR if --quiet is requested.
The filter prevents traceback logs on the console but these are still logged
to the logfile for diagnostic purposes.

logsetup must be called AFTER switching users, or strange things will happen.
"""

import logging

class DBCollectError(Exception):
    """Generic exception class"""
    pass

class TracebackInfoFilter(logging.Filter):
    """Clear or restore the exception on log records"""
    def __init__(self, clear=True):
        self.clear = clear
    def filter(self, record):
        if self.clear:
            record._exc_info_hidden, record.exc_info = record.exc_info, None
            # clear the exception traceback text cache, if created.
            record.exc_text = None
        elif hasattr(record, "_exc_info_hidden"):
            record.exc_info = record._exc_info_hidden
            del record._exc_info_hidden
        return True

def logsetup(logpath, debug = False, quiet=False):
    """Setup logging both to logpath and stderr"""
    level = logging.DEBUG if debug else logging.INFO
    logging.basicConfig(filename=logpath,
        filemode='w',
        level=logging.DEBUG,
        format="%(asctime)s:%(levelname)-8s: %(message)s",
        datefmt='%Y-%m-%d %I:%M:%S')

    consoleHandler = logging.StreamHandler()
    consoleHandler.addFilter(TracebackInfoFilter())
    if quiet:
        consoleHandler.setLevel(logging.ERROR)
    else:
        consoleHandler.setLevel(logging.INFO)
    consoleHandler.setFormatter(logging.Formatter('%(levelname)-8s : %(message)s', datefmt='%Y-%m-%d-%I:%M:%S'))
    logging.getLogger().addHandler(consoleHandler)
