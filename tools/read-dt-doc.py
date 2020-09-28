#!/usr/bin/python3

import argparse
from html.parser import HTMLParser
import os
import re
from urllib.request import Request, urlopen

# Toggle for formatting mode.
g_format = True


def fprint(*args, **kwargs):
  if not g_format:
    print(*args, **kwargs)


# Toggle for dch mode.
g_dch = False

# Define colors for pretty printing articles. Thanks: https://stackoverflow.com/a/17303428.


class TermFmt:
  PURPLE = '\033[95m'
  CYAN = '\033[96m'
  DARKCYAN = '\033[36m'
  # BLUE = '\033[94m'
  BLUE = '\033[95m'
  GREEN = '\033[92m'
  YELLOW = '\033[93m'
  RED = '\033[91m'
  BOLD = '\033[1m'
  UNDERLINE = '\033[4m'
  RESET = '\033[0m'

# Define a regex for detecting URLs. Thanks Django!
# https://github.com/django/django/blob/stable/3.1.x/django/core/validators.py


ul = '\u00a1-\uffff'  # Unicode letters range (must not be a raw string).

# IP patterns
ipv4_re = r'(?:25[0-5]|2[0-4]\d|[0-1]?\d?\d)(?:\.(?:25[0-5]|2[0-4]\d|[0-1]?\d?\d)){3}'
ipv6_re = r'\[[0-9a-f:.]+\]'  # (simple regex, validated later)

# Host patterns
hostname_re = r'[a-z' + ul + r'0-9](?:[a-z' + ul + r'0-9-]{0,61}[a-z' + ul + r'0-9])?'
# Max length for domain name labels is 63 characters per RFC 1034 sec. 3.1
domain_re = r'(?:\.(?!-)[a-z' + ul + r'0-9-]{1,63}(?<!-))*'
tld_re = (
    r'\.'                                # dot
    r'(?!-)'                             # can't start with a dash
    r'(?:[a-z' + ul + '-]{2,63}'         # domain label
    r'|xn--[a-z0-9]{1,59})'              # or punycode label
    r'(?<!-)'                            # can't end with a dash
    r'\.?'                               # may have a trailing dot
)
host_re = '(' + hostname_re + domain_re + tld_re + '|localhost)'

url_re = re.compile(
    r'^(?:[a-z0-9.+-]*)://'  # scheme is validated separately
    r'(?:[^\s:@/]+(?::[^\s:@/]*)?@)?'  # user:pass authentication
    r'(?:' + ipv4_re + '|' + ipv6_re + '|' + host_re + ')'
    r'(?::\d{2,5})?'  # port
    r'(?:[/?#][^\s]*)?'  # resource path
    r'\Z', re.IGNORECASE)


# Define our HTML parser. This parser converts everything wtihin the <article> element to a
# (hopefully) sane bulleted format.

class ChangelogParser(HTMLParser):
  # Number of spaces to have for each level of indentations.
  SPACES_PER_LEVEL = 2
  # Elements which constitute a newline and further level of indentation.
  LEVEL_ELEMENTS = ("h1", "h2", "h3", "li", "p")
  # Elements which should be bolded.
  BOLD_ELEMENTS = ("b", "strong", "em", "mark", "i", "code", "pre")

  # State

  # Whether the first line has been printed. This is necessary to not print a newline before that.
  first_line_printed = False
  # Whether we are currently in a <title> element.
  in_title = False
  # Whether we are currently in a <article> element.
  in_article = False
  # Whether we are currently under a <h1> element.
  in_h1 = False
  # Whether we are currently under a <h2> element.
  in_h2 = False
  # Whether we are currently under a <h3> element.
  in_h3 = False
  # Stack of href links.
  link_stack = []
  # Current level of indentation.
  current_indent = 0

  # Parser methods

  def handle_starttag(self, tag, attrs):
    # Handle special tags.
    if tag == "title":
      self.in_title = True
    elif tag == "article":
      self.in_article = True

    # Handle tags within <article>.
    if self.in_article:
      # Handle tags that start a new line.
      if tag in self.LEVEL_ELEMENTS:
        do_indent = True

        def drop_out_of_h2():
          if self.in_h2:
            self.current_indent = self.current_indent - 1
            self.in_h2 = False

        def drop_out_of_h3():
          if self.in_h3:
            self.current_indent = self.current_indent - 1
            self.in_h3 = False

        # Headers need special treatment:
        #   - If, say, we are in an <h1>, and encounter the start of another <h1>, we do not need to
        # change our indentation.
        #   - If we encounter a </h1>, we don't want to yet descend.
        #   - If we encounter a <h1> when we were last in a <h2>, we need to drop out of the <h2>.
        if tag == "h1":
          if self.in_h1:
            do_indent = False
          else:
            self.in_h1 = True
          drop_out_of_h2()
          drop_out_of_h3()
        elif tag == "h2":
          if self.in_h2:
            do_indent = False
          else:
            self.in_h2 = True
          drop_out_of_h3()
        elif tag == "h3":
          if self.in_h3:
            do_indent = False
          else:
            self.in_h3 = True

        if do_indent:
          self.current_indent += 1

        if not self.first_line_printed:
          self.first_line_printed = True
        else:
          # Print a newline *before* processing this tag. This is done to make lists work better.
          # For example:
          # - List Item 1
          #   - List Item 1.1
          #   - List Item 1.2
          # - List Item 2
          # If we only take care of newlines after tags, then we have to worry about where list item
          # 1 ends, which is actually pretty difficult to determine.
          print("")

        char = "-"
        if g_dch and self.current_indent == 1:
          char = "*"
        print("{}{} ".format(" " * self.current_indent * self.SPACES_PER_LEVEL, char), end="")
      # Handle tags that may require formatting.
      elif tag in self.BOLD_ELEMENTS:
        fprint(TermFmt.BOLD, end="")
      elif tag == "a":
        href = None
        for attr in attrs:
          if attr[0] == "href":
            try_href = attr[1]
            # See if the href is an absolute link.
            if url_re.findall(try_href):
              href = try_href
            # See if the href is a link within the site.
            else:
              # We don't care about links within this page.
              if not try_href.startswith("#"):
                try_href = "https://docs.donutteam.com" + try_href
                if url_re.findall(try_href):
                  href = try_href
        self.link_stack.append(href)

  def handle_endtag(self, tag):
    if tag == "title":
      self.in_title = False
    elif tag == "article":
      self.in_article = False
    if self.in_article:
      if tag in self.LEVEL_ELEMENTS:
        # If we're in a header, don't yet descend.
        if not tag == "h1" and not tag == "h2" and not tag == "h3":
          self.current_indent -= 1
      elif tag in self.BOLD_ELEMENTS:
        fprint(TermFmt.RESET, end="")
      elif tag == "a":
        href = self.link_stack.pop()
        if href:
          fprint(" ({}{}{}{})".format(TermFmt.UNDERLINE, TermFmt.BLUE, href, TermFmt.RESET), end="")

  def handle_data(self, data):
    # Strip any whitespace.
    data_stripped = os.linesep.join([s for s in data.splitlines() if s])
    if data_stripped:
      if self.in_title:
        fprint(TermFmt.BOLD + TermFmt.UNDERLINE + TermFmt.BLUE + data + TermFmt.RESET)

      # Don't print anything if we haven't yet indented.
      if self.in_article and self.current_indent != 0:
        print(data_stripped, end="")


def main():
  arg_parser = argparse.ArgumentParser()
  arg_parser.add_argument("-n", "--no-formatting", help="Disable formatting, not printing anything \
other than the plain page contents. This option omits the page title.", action="store_false")
  arg_parser.add_argument("-d", "--dch", help="Format for a Debian changelog.",
                          action="store_true")
  arg_parser.add_argument("page", help="The docs page to print. This may be a path relative to \
\"https://docs.donutteam.com/docs/\", or an absolute URL.")
  args = arg_parser.parse_args()

  global g_format
  g_format = not args.no_formatting

  global g_dch
  g_dch = args.dch

  page = args.page
  if not url_re.fullmatch(page):
    page = "https://docs.donutteam.com/docs/" + page
    if not url_re.match(page):
      raise ValueError("URL \"{}\" is ill-formed.".format(args.page))

  req = Request(page, headers={'User-Agent': 'MavisWalker Browser 6.0'})
  html = urlopen(req).read().decode("utf8")

  html_parser = ChangelogParser()
  html_parser.feed(html)
  print("")


if __name__ == "__main__":
  main()
