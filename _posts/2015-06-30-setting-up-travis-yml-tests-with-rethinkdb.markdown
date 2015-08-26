---
layout: post
title: Setting up Travis.yml tests with RethinkDB
date: 2015-06-30 14:01:21.000000000 -07:00
---
Because you're a good developer, you often write tests for the code you're writing. Because you're a really good developer, you often use tools like [Travis CI](https://travis-ci.org/) for continuous integration.

So you probably google "travis ci rethinkdb" and find [an example for running RethinkDB in Travis CI](http://docs.travis-ci.com/user/installing-dependencies/) in their website.

![Travis Screenshot](/assets/images/2015/07/travis-yml-rethinkdb.png)

After adding this to your `.travis.yml`, making your tests pass locally, and then pushing your changes to GitHub you see the following on Travis:

![](/assets/images/2015/07/travis-tests-failing.png)

Your tests fail! But they worked locally! What's going on! 

If you look at RethinkDB's documentation, you'll see that the instructions for installing RethinkDB are a bit different from the Travis CI example. The repository posted in Travis CI's website is outdated and installs an older version of RethinkDB that is probably different from your client driver version (which is what causes the problem).

![RethinkDB Install Page](/assets/images/2015/07/rethinkdb-install.png)

Fixing this is pretty simple. Just copy paste the commands posted on [the RethinkDB install page](http://rethinkdb.com/docs/install/ubuntu/) into your `.travis.yml` file.

```
before_install:
  - source /etc/lsb-release && echo "deb http://download.rethinkdb.com/apt $DISTRIB_CODENAME main" | sudo tee /etc/apt/sources.list.d/rethinkdb.list
  - wget -qO- http://download.rethinkdb.com/apt/pubkey.gpg | sudo apt-key add -
  - sudo apt-get update -q
  - sudo apt-get -y --force-yes install rethinkdb

before_script:
    - rethinkdb --daemon
```
