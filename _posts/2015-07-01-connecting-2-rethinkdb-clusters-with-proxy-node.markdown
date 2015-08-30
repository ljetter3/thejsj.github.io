---
layout: post
title: Connecting 2 RethinkDB clusters with proxy node
date: 2015-07-01 15:51:53.000000000 -07:00
---
Just yesterday, I got the following question on Twitter:

<blockquote class="twitter-tweet" lang="en"><p lang="en" dir="ltr"><a href="https://twitter.com/rethinkdb">@rethinkdb</a> is there any way to dynamically join a cluster? Trying to set up docker cluster, would be helpful to join after start.</p>&mdash; Andy Burke (@andybrk) <a href="https://twitter.com/andybrk/status/616010074687811584">June 30, 2015</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

The question makes complete sense. Often times, you start up a server and only want it to join a cluster later. For example, you might not know the host or port for one of the nodes in the cluster or you might want to add some data before having it join the cluser.

In this blog post, I'll show you how to add a node to a cluster after the node has been started. We'll do this using a RethinkDB proxy node, which doesn't hold any data. 

### Starting the cluster

The first thing we're going to do is start a new cluster with two nodes. We'll run all these nodes locally, but the mechanics of this wouldn't change for nodes in different hosts. Here, we'll start two nodes listening for intra cluster traffic on ports 4000 and 4001, listening for http traffic to the web admin on ports 5000 and 5001, listening for driver traffic on ports 6000 and 6001, and with server names "server_1" and "server_2". 

```bash
rethinkdb -d ./server_1 --server-name server_1 --cluster-port 4000 --http-port 5000 --driver-port 6000
```

After starting "`server_1`", we join it to "`server_2`" by passing the intra cluster address of "`server_1`" via the `--join` opt arg.

```bash
rethinkdb -d ./server-2 --server-name server_2 --cluster-port 4001 --http-port 5001 --driver-port 6001 --join localhost:4000
```

After executing these two commands, you can go to `http://localhost:5000#servers` where you will see that both nodes ("`server_1`, and `server_2`) are now connected. 

![Servers on intial setup](/assets/images/2015/07/servers1.png)

If you go to `http://localhost:5001#servers` (`server_2`'s web admin port), you will see exactly the same thing, because both servers know about each other.

### Adding a new node

Now, we are going to add a new node that will not be initially joined to the cluster. We'll call this server "`server_3`" and we'll have it listen in ports 4002, 5002, and 6002. 

```bash
rethinkdb -d ./server_3 --server-name server_3 --cluster-port 4002 --http-port 5002 --driver-port 6002
```

![](/assets/images/2015/07/server_3-starting.png)

After starting the server, we can go to `http://localhost:5002#server` and see that we have a cluster of 1 server with only "`server_3`".

![](/assets/images/2015/07/Screen-Shot-2015-07-01-at-4-46-28-PM.png)

It's important to understand that, because we didn't pass a `--join` opt-arg to our `rethinkdb` command, we created a new cluster of 1 node. If this cluster had 2 nodes and we joined one node with another node in the other cluster, we'd have a cluster of 4 nodes, not 3.

### Joining new node to cluster

After adding the new node, we now need to start another proxy node to join the new node to the cluster. We'll do this by passing two `--join` opt-args for the cluster's intracluster port and the new node's intracluster port.

```bash
rethinkdb proxy --server-name proxy_server --join localhost:4000 --join localhost:4002 --cluster-port 4003 --http-port 5003 --driver-port 6003
```

After running this command, we can go the web UI and see that our new node is now connected to the rest of the cluster. 

![](/assets/images/2015/07/connected-nodes.png)

The only problem is that now, the UI is telling us there's an issue in our database. If we inspect the issue, we can see the following: 

![](/assets/images/2015/07/issues-1.png)

The problem is that in both, our new node and our cluster, there was a database named "test", so now there are two databases name "test", which produces a name conflict. We can resolve these issues in the UI, by just renaming one of the databases. We can also resolve this issue using ReQL. In this case, we can use the following query to rename both "test" databases into "test_UUID-FRAGMENT"

```javascript
r.db('rethinkdb').table('current_issues')
  .filter({ type: 'db_name_collision' })
  .concatMap(function (row) {
    return row('info')('ids');
  })
  .forEach(function (id) {
    return r.db('rethinkdb').table('db_config').get(id)
      .update(function (issue)  {
        return {
          'name': issue('name').add('_').add(id.split('-')(0))
        };
      });
    })
```

Finally, after fixing all issues, you can shut down the proxy server. Since it's a proxy server, it has no data and won't cause any issues when shut down.

And that's it! You now have a cluster of 3 nodes. While this is not as straight-forward as it could be, this is a good, simple workaround for joining nodes together.
