#!/usr/bin/env python
#
# Version 2, December 2004
#
# Copyright (C) 2022 George Watson [gigolo@hotmail.co.uk]
#
# Everyone is permitted to copy and distribute verbatim or modified
# copies of this license document, and changing it is allowed as long
# as the name is changed.
#
# DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE TERMS AND CONDITIONS FOR
# COPYING, DISTRIBUTION AND MODIFICATION
#
# 0. You just DO WHAT THE FUCK YOU WANT TO.

"""
https://github.com/takeiteasy
Description: This is to get pass Cloudflare Anti-bot protection. Requires Selenium and Safari, only built for Macs. Could easily be ported to other systems (probably).
It's not ideal - but it's simple and it means I can avoid Node.js which is a big pile of horse shit that I want to avoid totally.
"""

from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from optparse import OptionParser
import sys, os, cookielib, requests

parser = OptionParser(usage="%prog [-u URL] [-t N] [-x]", version="%prog 1.0")
parser.add_option("-u", "--url", dest="url", help="URL to open", metavar="URL", default=None)
parser.add_option("-t", "--timeout", dest="timeout", help="Automatically close browser after timeout", metavar="N", default=None)
parser.add_option("-x", "--no-get", action="store_false", dest="use_get", default=True, help="Use source from Safari instead of GET request")
parser.add_option("-k", "--kill", action="store_true", dest="kill_safari", default=False, help="Kill Safari on completion")
parser.add_option("-f", "--focus", action="store_true", dest="focus_safari", default=False, help="Focus Safari because activating webdriver")
(options, args) = parser.parse_args()

if not options.url:
    parser.error("No URL provied")

if options.focus_safari:
    from subprocess import Popen, PIPE
    Popen(['osascript', '-'], stdin=PIPE, stdout=PIPE, stderr=PIPE).communicate('''
    tell application "Safari"
        activate
        set visible of first window to true
    end tell
    ''')

driver = webdriver.Safari()
driver.get(options.url)

if not options.timeout:
    os.system('read -s -n 1')
else:
    from time import sleep
    sleep(int(options.timeout))

if options.use_get:
    a = driver.get_cookies()
    driver.close()

    b = cookielib.CookieJar()
    for i in a:
        b.set_cookie(cookielib.Cookie(name=i['name'],value=i['value'],domain=i['domain'],path=i['path'],secure=i['secure'],rest=False,version=0,port=None,port_specified=False,domain_specified=False,domain_initial_dot=False,path_specified=True,expires=i['expiry'],discard=True,comment=None,comment_url=None,rfc2109=False))

    print requests.get(options.url, cookies=b, headers={'User-Agent': 'Mozilla/5.0 (X11; CrOS x86_64 11021.56.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.76 Safari/537.36'}).content
else:
    print driver.page_source.encode('utf-8')
    driver.close()

if options.kill_safari:
    os.system('killall Safari')
    
