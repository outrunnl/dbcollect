#!/usr/bin/env python
"""\
Strip SQL text from html formatted Oracle AWR reports

The SQL sections are replaced with a 'removed' message.
The files must be valid html files and have .html as extension,
other files will be ignored.
Sections to be removed:
* Top SQL tables (SQL Ordered by ...)
* Complete list of SQL text
* ADDM report
"""

_epilog = """\
Requirements: python 2 or 3, argparse, lxml (optional)
lxml is much faster, xml.ElementTree used as fallback if lxml is not installed.
Note that the xml parser re-orders the element attributes upon save.

Parsing errors can be caused by small linesize in SQL*Plus causing html tags
to be broken. To fix, use a very large linesize:
SET LINESIZE 32767

Copyright (c) 2023 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import os
import sys
import re
import logging

try:
    from lxml import etree
except ImportError:
    from xml.etree import ElementTree as etree

_deleted = 'Section removed by awrstrip'

def awrstrip(path, out=None, inplace=False):
    """Strip a html formatted AWR report from sections containing SQL text.
    The ADDM report is also removed as it also often contains SQL code.

    Parameters:
    path: file to be processed (must be valid html)
    out: path to save file as (not saved if none)
    inplace: save to same file if True

    Returns:
    None
    """
    if 'lxml' not in sys.modules:
        logging.debug('python-lxml package not found, fallback to slower xml package')
    try:
        tree = etree.parse(path)
    except etree.ParseError:
        logging.error('Parsing error in %s, not stripped', path)
        return
    blacklist = []
    try:
        iter = tree.iter
    except:
        # Need this on Python 2.6
        iter = tree.getiterator
    for element in iter():
        if element.tag == 'table':
            # Look for tables with 'SQL' in the 'summary' attribute
            summary = element.get('summary')
            if summary:
                if re.search(r"top sql|sql statements", summary, re.I):
                    #logging.debug('removing table "%s"', summary.replace('\n',''))
                    blacklist.append(element)
        elif element.tag == 'pre':
            # Look for a separate <pre> section starting with ADDM
            if element.text and element.text.strip().startswith('ADDM'):
                #logging.debug('removing section "ADDM Report"')
                blacklist.append(element)
    changed = False
    for elem in blacklist:
        changed = True
        elem.clear()
        elem.tag = 'h3'
        elem.text = _deleted
    if inplace is True:
        out = path
    if out and changed:
        try:
            tree.write(out, encoding="utf-8")
        except IOError as err:
            logging.error('IO Error writing to %s: %s', out, os.strerror(err.errno))
