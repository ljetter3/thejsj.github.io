---
layout: post
title: 'Django and Realtime: Using Django with Tornado and RethinkDB'
date: 2015-05-15 11:16:02.000000000 -07:00
---

Over the last couple of months, I've been writing a lot of Node.js code using 
RethinkDB. After writing so much JavaScript, I started missing Python and Django, 
which I've used extensively over the years. Because of this, I decided to port 
on of my original [Node.js RethinkDB chat apps](https://github.com/thejsj/rethinkdb-chat) 
to Django as way to compare the Django and Node.js.

In this blog post, I'll take you through the basics of making a realtime app in 
Django. You can find the [final repository on GitHub](https://github.com/thejsj/django-and-rethinkdb). 
In the app, the user has to login (done with Django authentication) and can then writes messages that get sent through a socket connection to the server. A RethinkDB query listens for new messages and pushes changes to the client through a socket connection. We'll use Tornado to handle our socket connections and redirect HTTP request to our Django app.

### 1. Setting up a basic Django app

Because our chat app will work as a single page application, we'll start by creating the `index.html` file that will server as our only view. We'll create this `index.html` [as a template](https://github.com/thejsj/django-and-rethinkdb/blob/master/django_and_rethinkdb/templates/index.html) inside our main Django app. We'll show our chat messages if the user is authenticated and show a login/signup form if the user is not:

```
  <!-- Omitted -->
    <div ui-view id='container' class='messages'></div>
  <!-- Omitted -->
  <!-- Omitted -->
    <form action="/auth/login/" method="post">
      <!-- Omitted -->
    </form>
    <form action="/auth/signup/" method="post">
      <!-- Omitted -->
    </form>
  <!-- Omitted -->
```

For each form, we reference the appropriate view that will handle login and signup. After creating our template, we'll add a view to render it at the root of our app: 

```
def main(request):
    return render(request, 'index.html')
```

We'll use Django authentication to login users. In our `views.py` file, we [set some basic views](https://github.com/thejsj/django-and-rethinkdb/blob/master/django_and_rethinkdb/views.py#L13-L35) to handle a user logging in and signing up. This is pretty standard Django logic.

```
def login(request):
    username = password = ''
    if request.POST:
        form = LoginForm(request.POST)
        if form.is_valid():
            user = auth.authenticate(
                username=form.cleaned_data['username'],
                password=form.cleaned_data['password']
            )
            if user is not None and user.is_active:
                auth.login(request, user)
                return HttpResponse('User %s logged in' % form.cleaned_data['username'])
        return HttpResonse('Error logging user in')
    raise PermissionDenied

def signup(request):
    if request.POST:
        form = RegistrationForm(request.POST)
        if form.is_valid():
            form.save()
            return HttpResponse('User %s Created' % form.cleaned_data['username'])
        return HttpResonse('Error in SignUp')
    raise PermissionDenied
```

Now that we have our basic template and our views, we can signup and authenticate users and start working on the messages portion fo the application.

### 2. Wrapping Tornado Over Django

Now is when things tart to diverge a little bit from the usual Django way of doing things. Instead of sending HTTP request directly to Django, we're going to route them through Tornado. Because of this, we'll need to bootstrap Django and load settings ourselves. 

First, we'll create a file called [`tornado_main.py`](https://github.com/thejsj/django-and-rethinkdb/blob/master/django_and_rethinkdb/tornado_main.py) which will be our new main file to run our Django app. This file setups our Django app, then creates a tornado application, which then routes to our Django app and starts listening for traffic on a port.

```
import django.core.handlers.wsgi
from django.conf import settings
import tornado

django.setup()

def main():
  tornado.parse_command_line()
  wsgi_app = tornado.wsgi.WSGIContainer(
    django.core.handlers.wsgi.WSGIHandler()
  )
  tornado_app = tornado.web.Application([
    ('.*', tornado.web.FallbackHandler, dict(fallback=wsgi_app)),
  ])
  server = tornado.httpserver.HTTPServer(tornado_app)
  server.listen(8000)
  tornado.ioloop.IOLoop.instance().start()

if __name__ == '__main__':
  main()
```
Because we're routing our requests through Tornado, we can't use the usual `python manage.py runserver` for development. Instead, we call the `tornado_main.py` passing in our `PYTHONPATH` and our settings:

```
export PYTHONPATH=.; 
export DJANGO_SETTINGS_MODULE=django_and_rethinkdb.settings; python django_and_rethinkdb/tornado_main.py
```
Our Django app is now working with Tornado:

![Django App With Tornado](/assets/images/2015/05/Screen-Shot-2015-05-15-at-1-42-51-PM.png)

### 3. Adding Socket Connections

Now that we've created some views, added authentication and are routing our HTTP request through tornado, it's time to create a socket handler for our web socket connections. 

It's important to understand why were using Tornado to handle web socket connections. Web socket connections are often idle. By using non-blocking IO, Tornado is ideal for tens of thousands of open connections. 

The first thing we do to add these socket connection is add a socket handler at [`/new-messages`](https://github.com/thejsj/django-and-rethinkdb/blob/master/django_and_rethinkdb/tornado_main.py#L28):

```
from change_feed import SocketHandler

  # ...

  tornado_app = tornado.web.Application([
    ('/new-messages/', SocketHandler),
    ('.*', tornado.web.FallbackHandler, dict(fallback=wsgi_app)),
  ])
```

Then, in another file called `change_feeds.py`, we create `SocketHandler` class, which inherits from `tornado.websocket.WebSocketHandler`. This class will have three methods: `open` (when a connection is opened), `on_close` (when a connection is closed), and `on_message` (when a message is sent from the client to the server). 

```
clients = []

class SocketHandler(tornado.websocket.WebSocketHandler):

    def open(self):
        self.stream.set_nodelay(True)
        if self not in clients:
            clients.append(self)
        print len(clients)

    def on_message(self, message):
        # TODO: Write What happens when we get a message

    def on_close(self):
        for i, client in enumerate(clients):
            if client is self:
                del clients[i]
                return
```

When we get a new client connection, we store it in our client array and then delete it when the client close the connection. 

When we get a new message, we're going to store that message in [RethinkDB](rethinkdb.com). RethinkDB is NoSQL database made for realtime apps. It can listen to changes in your database and notify you about those changes. It also comes with [Tornado integration](http://rethinkdb.com/api/python/set_loop_type/), so we can query the database without blocking. In order to implement this we're going to import RethinkDB, set the loop type to `"tornado"`, convert our `on_message` method into a Tornado coroutine, and then insert our messages asynchronously using `yield`.

```
import rethinkdb as r
import json

r.set_loop_type('tornado')

class SocketHandler(tornado.websocket.WebSocketHandler):

    @tornado.gen.coroutine
    def on_message(self, message):
        new_message_object = json.loads(message)
        conn = yield r.connect(host="localhost", port=28015)
        new_message = yield r.db("rethinkdb_chat").table('messages').insert(new_message_object).run(conn)
      
```

Now, [open a web socket connection in the client at `/new-messages`](https://github.com/thejsj/django-and-rethinkdb/blob/master/django_and_rethinkdb/static/app/services.js#L12) and [send a message](https://github.com/thejsj/django-and-rethinkdb/blob/master/django_and_rethinkdb/static/app/services.js#L46-L50), the message gets inserted into a 'messages' table in RethinkDB.

- Noticed how we're not using views or models

### 4. Listening For Changes

Now that we're adding messages through our socket connection, we have to start listening for changes on our 'messages' table. For that, we'll create a function called `print_changes`, which we'll add as a callback to Tornado.

In `tornado_main.py`, we add: 

```
from change_feed import print_changes, SocketHandler

def main():
  # ... Omitted ...
 tornado.ioloop.IOLoop.current().add_callback(print_changes)
  tornado.ioloop.IOLoop.instance().start()
```
Then, in our `change_feeds.py`, we add our `print_changes` function.

```
@tornado.gen.coroutine
def print_changes():
    conn = yield r.connect(host="localhost", port=28015)
    feed = yield r.db("rethinkdb_chat").table('messages').changes(include_states=False).run(conn)
    while (yield feed.fetch_next()):
        change = yield feed.next()
        for client in clients:
            client.write_message(change)
```

This function will send our client a message every time there's a change in our 'messages' table. The way this works is that RethinkDB listens to changes that table and calls then `write_message` method on every client whenever there's a new change. RethinkDB works well for this because we don't have to constantly poll the database for changes, which is what we would need to do if we were using Django's ORM or a SQL database. We could however, use Django models in conjunction with RethinkDB's changefeeds to query data and send it to the user. 

### The Problem With All This

Django and its MVC (or MVT) model are great for HTTP apps. Views make perfect sense when the user makes a request on a URL and gets back some HTML or a JSON object. Django and MVC doesn't make as much sense for realtime apps, where the backend needs to push changes to the client based on changes. Socket handlers usually require a listener of some sort, with some logic to push to the clients and thin handlers for when the clients sends over a new message. 

What I've done is something closer to two separate systems where, thanks to Tornado, I can separate my socket handlers from my Django logic, but I'm able to use to still use Django for my HTTP request and Django models and functionality inside my socket handlers.
