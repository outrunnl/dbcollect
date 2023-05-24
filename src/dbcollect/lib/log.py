"""
log.py - Manage DBCollect logging
Copyright (c) 2023 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+

logsetup sets up dual logging via separate handlers, one is the dbcollect logfile
which logs at DEBUG level (most everything)
the other is the consolehandler which logs at INFO or ERROR if --quiet is requested.
The filter prevents traceback logs on the console but these are still logged
to the logfile for diagnostic purposes.

logsetup must be called AFTER switching users, or strange things will happen.
"""

import sys, logging

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
    consoleHandler.setFormatter(logging.Formatter('%(levelname)-8s : %(message)s', datefmt='%Y-%m-%d-%H:%M:%S'))
    logging.getLogger().addHandler(consoleHandler)

def exception_handler(func):
    """Decorator to catch CTRL-C and other exceptions (multiprocessing)
    This prevents a mess of error messages from different processes
    """
    def inner(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except KeyboardInterrupt:
            logging.warning('%s interrupted', func.__name__)
            sys.exit(1)
        except Exception as e:
            logging.exception('Exception in %s: %s', func.__name__, e)
            sys.exit(99)
    return inner
