"""
threads.py - Threading functions for dbcollect
Copyright (c) 2021 - Bart Sjerps <bart@outrun.nl>
License: GPLv3+
"""
import threading, logging

class Lock():
    """Simple context manager for lock"""
    lock = threading.Lock()
    def __enter__(self):
        self.lock.acquire()
    def __exit__(self ,type, value, traceback):
        self.lock.release()

lock = Lock()
