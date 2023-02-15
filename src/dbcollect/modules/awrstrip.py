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
                    logging.debug('removing table "%s"', summary.replace('\n',''))
                    blacklist.append(element)
        elif element.tag == 'pre':
            # Look for a separate <pre> section starting with ADDM
            if element.text and element.text.strip().startswith('ADDM'):
                logging.debug('removing section "ADDM Report"')
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

if __name__=='__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__, epilog=_epilog,
            formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("-n", "--dryrun",  action="store_true", help="Do not overwrite files")
    parser.add_argument("-D", "--debug",   action="store_true", help="Show actions")
    parser.add_argument("-i", "--inplace", action="store_true", help="Replace file")
    parser.add_argument(      "--dir",     type=str, default='/tmp', help="Save directory")
    parser.add_argument("-q", "--quiet",   action="store_true", help="Quiet")
    parser.add_argument("FILE", nargs='*', help='files or directories to be processed')
    args = parser.parse_args()

    if args.debug:
        logging.basicConfig(level='DEBUG', format='%(levelname)s: %(message)s')
    elif args.quiet:
        logging.basicConfig(level='ERROR', format='%(levelname)s: %(message)s')
    else:
        logging.basicConfig(level='INFO', format='%(levelname)s: %(message)s')
    for path in args.FILE:
        if os.path.isfile(path):
            if args.dir:
                awrstrip(path, out=os.path.join(args.dir, os.path.basename(path)), inplace=args.inplace)
        elif os.path.isdir(path):
            for file in [os.path.join(path, f) for f in os.listdir(path) if f.endswith('.html')]:
                awrstrip(file, '/tmp/out.html')
