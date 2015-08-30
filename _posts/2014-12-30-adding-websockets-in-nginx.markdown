---
layout: post
title: Adding WebSockets in Nginx
date: 2014-12-30 01:24:40.000000000 -08:00
---
For my thesis Hack Reactor thesis project, I'm currently working on an application that uses websockets. In my server setup, I have an HTTP server for most operations and a websockets server running [shareJS](http://sharejs.org/). My HTTP server is a node/express server listening in port 8005 and my websocket server is listening on port 8007. Before setting up websocktes, I redirect all traffic to port 8005. Here's how my nginix virutal host looks when handling only HTTP requests:

```nginx
server {
    # the port your site will be served on
    listen      80;

    server_name YOUR_DOMAIN.com;

    location / {
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header HOST $http_host;
        proxy_set_header X-NginX-Proxy true;

        proxy_pass http://127.0.0.1:8005;
    }
}
```

In order to add websockets, we need to make a couple of changes. First, we need to add some configuration to let nginx know we can use websockets, through the use of HTTP 1.1:

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}
upstream websocket {
    server localhost:8007;
}
```

After that, we're going to start listening on all ports through `listen *` (for simplicity) and then go into `location /` to configure this connection as an HTTP 1.1 connection. 

```nginx
map $http_upgrade $connection_upgrade { ... }
upstream websocket { ... }

server {
    # the port your site will be served on
    listen      *;

    server_name YOUR_DOMAIN.com;

    location / {
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header HOST $http_host;
        proxy_set_header X-NginX-Proxy true;

        proxy_pass http://127.0.0.1:8005;
        
        // Set HTTP Version to 1.1
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_redirect off;
    }
}
```

And that's it! Websocket traffic on port 8007 will be redirect to your server on port 8007 and HTTP traffic on port 80 will be redirect to port 8005. 
