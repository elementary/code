#!/usr/bin/env python
"""Script which takes one or more file paths and reports on their detected
encodings

Example::

    % chardetect.py somefile someotherfile
    UTF-8
    ISO-8859-1

If no paths are provided, it takes its input from stdin.

It was properly modified to fit with scratch text editor project.
Original version was from the creators of python-chardet.

"""
from sys import argv, stdin

from chardet.universaldetector import UniversalDetector


def encoding_of(file, name='stdin'):
    """Return a string describing the probable encoding of a file."""
    u = UniversalDetector()
    for line in file:
        u.feed(line)
    u.close()
    result = u.result
    if result['encoding']:
        return result['encoding'].upper ()
    else:
        return 'error'


def main():
    if len(argv) <= 1:
        print description_of(stdin)
    else:
        for path in argv[1:]:
            print encoding_of(open(path, 'rb'), path)


if __name__ == '__main__':
    main()
