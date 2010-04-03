#! /usr/bin/env python

import os
from os.path import join as catfile
import random
import simplejson as json
import sqlite3
import sys
import time
import urllib2
from urllib import urlencode
#from email.utils import parsedate

# Read the Twungot posting configuration file.

cfgfile = open(sys.argv[1])
cfg = json.load(cfgfile)
cfgfile.close()

# Connect to the tweet-reply DB.

db = sqlite3.connect(catfile(cfg['dir'], cfg['db']))

# Set some special "compile-time" constants.

url_update = 'http://api.twitter.com/1/statuses/update.json'
url_mentions = 'http://api.twitter.com/1/statuses/mentions.json'

user_agent = 'twungot-poster/0.1'

gen_script = catfile(cfg['dir'], 'twungot-generate.pl')

# Functions.

def get_json(url, data=None, user=None, password=None):
    """Fetch a JSON-formatted API page."""

    if user is not None:
        pw_mgr = urllib2.HTTPPasswordMgrWithDefaultRealm()
        pw_mgr.add_password(None, url, user, password)
        pw_handler = urllib2.HTTPBasicAuthHandler(pw_mgr)
        opener = urllib2.build_opener(pw_handler)
    else:
        opener = urllib2.build_opener()

    req = urllib2.Request(url)
    req.add_header('User-Agent', user_agent)
    if data is not None:
        req.add_data(urlencode(data))

    url = opener.open(req)
    data = json.load(url)
    url.close()

    return data

def tweet(user, password, text):
    """Post a Tweeter update."""

    data = get_json(url_update, (('status', text.encode('utf-8')),), user, password)
    return data

def get_mentions(user, password, prev):
    """Fetch the few last tweets mentioning the user."""

    reqdata = []
    if prev > 0: reqdata.append(('since_id', prev))
    data = get_json(url_mentions, reqdata, user, password)

    if type(data) is not list: return []
    return sorted(data, lambda x, y: cmp(x['id'], y['id']))

def generate(model, title=None):
    """Generate a tweet text."""

    if model.has_key('command'):
        title = ''
        gen = os.popen(model['command'], 'r')

    else:
        if title is None:
            title = 'About %s: ' % model['title']

        cmd = "%s '%s' '%s' %d" % (gen_script,
                                   catfile(cfg['dir'], model['tokens']),
                                   catfile(cfg['dir'], model['model']),
                                   140 - len(title))

        gen = os.popen(cmd, 'r')

    text = gen.read()
    gen.close()

    if model.has_key('encoding'):
        text = text.decode(model['encoding'], 'ignore')

    return title + text.strip()

def test_replied(status):
    """Check if we have already replied to given status."""

    c = db.cursor()

    c.execute('select id from replied where id = ?', (status,))
    existing = c.fetchall()

    if len(existing) > 0:
        existing = True
    else:
        existing = False
        c.execute('insert into replied values (?)', (status,))
        db.commit()

    c.close()

    return existing

# Main loop.

prev_mentions_check = 0
prev_reply_tweet = 0

while True:
    # Generate predetermined tweets.

    for model in cfg['models']:
        if random.randint(1, model['period']) > 1: continue

        user = model.get('username', cfg['username'])
        password = model.get('password', cfg['password'])

        text = generate(model)
        result = tweet(user, password, text)

        print "[%s] Tweeted: %s (%s)" % (time.strftime('%Y-%m-%d %H:%M:%S'), text, user)

    # If it is time, check and reply to @mentions.

    if time.time() > prev_mentions_check + 600:
        prev_mentions_check = time.time()

        mentions = get_mentions(cfg['username'], cfg['password'], prev_reply_tweet)

        for status in mentions:
            prev_reply_tweet = status['id']
            if test_replied(status['id']): continue

            text = generate(cfg['models'][0], '@%s ' % status['user']['screen_name'])
            result = tweet(cfg['username'], cfg['password'], text)

            print "[%s] Replied: %s" % (time.strftime('%Y-%m-%d %H:%M:%S'), text)

    time.sleep(60)
