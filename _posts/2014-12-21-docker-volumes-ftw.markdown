---
layout: post
title: 'Storing Persistent Data in Docker: Docker `volumes` FTW!'
date: 2014-12-21 20:02:33.000000000 -08:00
---
Over the years, I've been teaching myself deployment and DevOps. A couple of months ago, I started learning [Docker](http://docker.com). Docker is a great way to keep your application environments consistent... but you're reading this blog post, so you probably already knew that already!

The other day, messing around with some of my containers, I restarted this ghost blog. Accidentally, I deleted all my database (SQLLite) and my images. These were obviously in their own volumes (so they were being stored persistently), but I had a [stupid line in init script that deleted all the data in my volumes](https://github.com/thejsj/Blog/blob/bceb264d39aa12ace7d49efb5d3ce33c06c9fc36/start.bash#L20-L27). At that point I realized that, while I was setting up my volumes correctly, I needed to make backing-up and transferring my data easier and I couldn't figure out a nice way to do that if my data was inside the container. 

In Docker, if you set up a volume, you can access it's contents by getting the volume directory through `docker inspect`. You can also use `docker cp` to copy the contents form the container into your host file system. These approaches might have solved my problem, but they seemed a little cumbersome.

### Solving The Problem: `volumes`

I ended up using `volumes` to mount directories from my host system into my containers. I didn't really know this was possible until I found this in the Docker documentation the other day. Basically, I changed my `.gitignore` to exclude my database and images and added directories in my project directory for each of them. Once I did that, I mounted my directories into my volume through my fig file (you are using [fig](http://fig.sh), right?).

Here's how that looks:
```
ghost:
  build: .
  volumes:
   - ./content/data:/ghost-override/content/data
   - ./assets/images:/ghost-override/assets/images
  ports:
   - "80:2368"
  environment:
    - BLOG_URL=docker.dev
```

This approach has some drawbacks (I'll talk about those later) but it's simple to manage and understand. Your images and your database are in your host file system. When a new image is created in your container, it's also in your host (`./assets/images`). When the database is updated, it's right there (`./content/data/ghost.db`). This setup works particularly work for synchronizing local and remote servers. 

I use Fabric to deploy, push, pull and sync my local and remote. Here's how that looks:

```
from fabric.api import *
from fabric.colors import green, red
import datetime
import time
from shutil import copyfile
from fabric.contrib.project import rsync_project

env.host_string = IP_ADDRESS
env.user = 'root'
ts = time.time()
st = datetime.datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H-%M-%S')

def deploy():
    """This pushes to production"""
    with cd('/apps/blog'):
        run('pwd')
        run('git stash')
        run('git pull -f origin master')
        run('fig -f prod.yml build')
        run('fig -f prod.yml up -d')

def push_db():
    # Doesn't really work!
    """Backup Data And Push DB"""
    copyfile('./content/data/ghost.db', './content/data/ghost-' + str(st) + '-local.db.bak')
    with cd('/apps/blog/content/data'):
        get('ghost.db', './content/data/ghost-' + str(st) + '-remote.db.bak')
        put('./content/data/ghost.db', './ghost.db')
    with cd('/apps/blog'):
        run('fig -f prod.yml stop')
        run('fig -f prod.yml up -d')

def pull_db():
    # Doesn't really work!
    """Backup Data And Pull DB"""
    copyfile('./content/data/ghost.db', './content/data/ghost-' + str(st) + '-local.db.bak')
    with cd('/apps/blog/content/data'):
        get('ghost.db', './content/data/ghost-' + str(st) + '.db.bak')
        get('ghost.db', './content/data/ghost.db')
    with cd('/apps/blog'):
        run('fig -f prod.yml stop')
        run('fig -f prod.yml up -d')

def sync_images():
    """Sync Local and Remote Images"""
    rsync_project(remote_dir='/apps/blog/content/', local_dir='./assets/images')
```

### Why What I Just Told You Is Wrong

This setup works pretty well for my simple local/remote setup, but it's not the docker way of doing is. If you take a look at [this article](http://www.tech-d.net/2013/12/16/persistent-volumes-with-docker-container-as-volume-pattern/) (the comments are particularly interesting) you'll notice that you can create containers that only contains your data. Storing persistent data that way increases portability and saves you from some permissions problems. These containers are usually very minimal and don't need to get modified, so you don't really need to remove them or change them. 

This pattern made sense to me and I've used it in other places, but it doesn't seem to be good when you want to copy/update data in and out of the container (like I'm currently doing), so I decided to not implement it.

Ultimately, I see my `volumes_from` pattern as a transition pattern between a more understandable setup that works well for single local/remote instances and a more robust setup that lets Docker manage data containers. 

### How I Recovered My Blog

In case your curious how I recovered over 10 blogs posts I lost when I deleted my database, here's how: Google's Page Cache.

![Jorge Silva - Cached Results](/assets/images/2014/12/Screen-Shot-2014-12-28-at-5-34-48-PM.png)
