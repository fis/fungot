#! /usr/bin/env python

import os
from os.path import join as catfile
import random
import simplejson as json
import sys
import time
import urllib2
from urllib import urlencode
#from email.utils import parsedate

# Read the Twungot posting configuration file.

cfgfile = open(sys.argv[1])
cfg = json.load(cfgfile)
cfgfile.close()

# Set some special "compile-time" constants.

url_update = 'http://api.twitter.com/1/statuses/update.json'
user_agent = 'twungot-poster/0.1'

gen_script = catfile(cfg['dir'], 'twungot-generate.pl')

# Functions.

def tweet(user, password, text):
    """Post a Tweeter update."""

    pw_mgr = urllib2.HTTPPasswordMgrWithDefaultRealm()
    pw_mgr.add_password(None, url_update, user, password)

    pw_handler = urllib2.HTTPBasicAuthHandler(pw_mgr)

    opener = urllib2.build_opener(pw_handler)

    req = urllib2.Request(url_update)
    req.add_header('User-Agent', user_agent)
    req.add_data(urlencode((('status', text),)));
    url = opener.open(req)

    data = json.load(url)
    url.close()

    return data

def generate(model):
    """Generate a tweet text."""

    title = 'About %s: ' % model['title']

    cmd = "%s '%s' '%s' %d" % (gen_script,
                               catfile(cfg['dir'], model['tokens']),
                               catfile(cfg['dir'], model['model']),
                               140 - len(title))

    gen = os.popen(cmd, 'r')
    text = gen.read()
    gen.close()

    return title + text.strip()

# Main loop.

while True:
    # Generate predetermined tweets.

    for model in cfg['models']:
        if random.randint(1, model['period']) > 1: continue

        text = generate(model)
        result = tweet(sys.argv[1], sys.argv[2], text)

        print "[%s] Tweeted: %s" % (time.strftime('%Y-%m-%d %H:%M:%S'), text)

    time.sleep(60)
