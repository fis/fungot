#! /usr/bin/env python

import random
import simplejson as json
import sqlite3
import time
import urllib2
from email.utils import parsedate

url_trends = 'http://search.twitter.com/trends.json'
rpp = 64
wait_time = 600

db = sqlite3.connect('/users/htkallas/twungot/tweets.sqlite3')
db_keys = ('id', 'text', 'created_at', 'from_user_id', 'to_user_id')

user_agent = 'twungot-collector/0.1'

# Functions.

def get_trend():
    """Return a random current Twitter trend search URL."""

    try:
        req = urllib2.Request(url_trends)
        req.add_header('User-Agent', user_agent)
        url = urllib2.urlopen(req)
        if url is None: return None

        data = json.load(url)
        url.close()

        if type(data) is not dict: return None
        if 'trends' not in data: return None

        trends = data['trends']

        if type(trends) is not list: return None
        if len(trends) == 0: return None

        trend = random.choice(trends)

        if type(trend) is not dict: return None
        if 'url' not in trend: return None

        return trend['url'].replace('/search?', '/search.json?')

    except IOError:
        return None

def get_tweets(url_base):
    """Return a list of tweets for a given trend search URL."""

    try:
        url_query = "%s&lang=en&rpp=%d" % (url_base, rpp)
        req = urllib2.Request(url_query)
        req.add_header('User-Agent', user_agent)
        req.add_header('Referer', url_trends)
        url = urllib2.urlopen(req)
        if url is None: return []

        data = json.load(url)
        url.close()

        if type(data) is not dict: return []
        if 'results' not in data: return []

        results = data['results']

        if type(results) is not list: return []

        for r in results:
            r['created_at'] = time.mktime(parsedate(r['created_at']))

        return results

    except IOError:
        return []

def save_tweets(tweets):
    """Saves new tweets into the database."""

    c = db.cursor()

    for tweet in tweets:
        t = tuple(tweet[k] for k in db_keys)
        c.execute('insert into tweets values (?, ?, ?, ?, ?)', t)

    db.commit()
    c.close()

# Main loop.

while True:
    trend = get_trend()
    tweets = get_tweets(trend)
    save_tweets(tweets)

    print "[%s] Added %d tweet(s) from: %s" % (time.strftime('%Y-%m-%d %H:%M:%S'), len(tweets), trend)
    time.sleep(wait_time)
