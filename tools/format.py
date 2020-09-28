#!/usr/bin/python3

import fileinput
import re
from textwrap import TextWrapper


# Prints text wrapped at 80 lines, with indentation preserved.

def main():
  wrapper = TextWrapper(width=80)
  leading_whitespace_re = re.compile(r"^\s+")
  for line in fileinput.input():
    current_indent = leading_whitespace_re.search(line).end()
    wrapper.subsequent_indent = " " * (current_indent + 2)
    print(wrapper.fill(line))


if __name__ == "__main__":
  main()
