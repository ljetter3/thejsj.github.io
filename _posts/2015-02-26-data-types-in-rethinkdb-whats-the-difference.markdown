---
layout: post
title: 'The Life Of A ReQL Query: Going Through All of RethinkDB''s Data Types'
date: 2015-02-26 11:36:36.000000000 -08:00
---
So you've been writing a lot of [ReQL](http://rethinkdb.com/api/javascript/) or have started messing around with it. You (obviously) love writing queries in it, but sometimes you get weird errors like `Expected type SELECTION but found SEQUENCE`. What does that  mean? What's a selection? What's a sequence? And why am I getting this error?

------

If you're not familiar with RethinkDB, you should [check it out](http://rethinkdb.com). 
It's the first open source database made for real-time applications (and it is wonderful!). 

----

In this blog post we'll be using some Caltrain data ([scraped from their site](http://www.caltrain.com/schedules/weekdaytimetable.html)) to write one single query. With this query, we'll try to understand the different data types in RethinkDB and how queries are transformed through the different ReQL methods. In case you're curious, this is what the query looks like:

```javascript
r.db('caltrain').table('trains')
 .between(300, 400, {'index': 'number'})
 .orderBy({'index': 'number'})
 .filter({'direction': 'north'})
 .pluck('number', 'stations')
 .hasFields({'stations': {'22nd-street': true}})
 .orderBy('stations', '22nd-street')
```

The result will be an array that looks like this: 

```javascript
[
  {
    "number": 365 ,
    "stations": {
      "22nd-street":  "17:19" ,
      "menlo-park":  "16:46" ,
      "millbrae":  "17:07" ,
      "mountain-view":  "16:35" ,
      "palo-alto":  "16:43" ,
      "redwood-city":  "16:52" ,
      "san-francisco":  "17:26" ,
      "san-jose":  "16:23"
    }
  },
  ... // 4 more trains
```

### Follow Along With Real Data

If you want to follow along with the same data set and already installed RethinkDB, you can just run this in your terminal:

```bash
curl -o caltrain-data.tar.gz http://thejsj.com/2015/caltrain-data/caltrain-rethinkdb-dump.tar.gz && rethinkdb restore caltrain-data.tar.gz
```

If you haven't installed RethinkDB, [go to RethinkDB's website and install it](http://rethinkdb.com/docs/install/). You can also just [download the database dump for this database](http://thejsj.com/2015/caltrain-data/caltrain-rethinkdb-dump.tar.gz). The .tar.gz contains a `caltrain` database with two tables: `trains` and `stations`.

### It All Starts With A Table

The first thing we need to start this query is to get our table. In this case, our table's name is `'trains'`. Our query returns a list of documents with information on different trains.

```javascript
r.db('caltrain').table('trains')
```

If we run `typeOf` on this query, we get `TABLE`.

```javascript
r.db('caltrain').table('trains')
 .typeOf() // "TABLE"
```

`"TABLE"` is our main storage type. It contains what are called 'documents'. Documents are similar to rows in  [RDBMSs](http://en.wikipedia.org/wiki/Relational_database_management_system). We can `.insert`, `.update`, and `.delete` documents into our table. Some methods, like `.getAll` can only be called on tables, since they need to refer to all documents in a table in order to return an accurate response.

### From Table To Table Slice

After specifying our table, we want to query all the trains in the database numbered between 300 and 400. Trains with a `number` from 300 to 400 represent weekday express trains (meaning they only stop at important stops). Our `.between` operation can only be run on tables, since it requires all indexes.

```javascript
r.db('caltrain').table('trains')
 .between(300, 400, {'index': 'number'})
 // .typeOf() "TABLE_SLICE"
```

This query returns a type of `"TABLE_SLICE"`. Table slices have methods and functionality that are close to a table, but that don't require all documents. We can, for example, sort the documents in this array by the index 'number' (provided we [created that index earlier](http://rethinkdb.com/api/javascript/#index_create)). 

```javascript
r.db('caltrain').table('trains')
 .between(300, 400, {'index': 'number'})
 .orderBy({'index': 'number'})
 // .typeOf() "TABLE_SLICE"
```

This returns a table slice with all documents with a `number` between 300 and 400, sorted by their `number` attribute.

### From Table Slice To `Selection<Stream>`

After filtering and sorting through these documents, we now want to filter through the trains that are going north, which is specified by the `direction` attribute. Unlike the `number` attribute, `direction` is not an index. That means we'll need to use the `.filter` command.

```javascript
r.db('caltrain').table('trains')
 .between(300, 400, {'index': 'number'})
 .orderBy({'index': 'number'})
 .filter({'direction': 'north'})
 // .typeOf() "SELECTION<STREAM>"
```

This query returns a `Selection<Stream>` type. `Selection<Stream>` loses some of the functionality provided by indexes. Because the result of this query is still a selection, we keep the reference to the document in the database each document points to. This means we can still `.update` and `.delete` these documents if we wanted to and those actions will be reflected on the database. 

Keep in mind that a selection is not really a data type. Selections are more like wrappers. They wrap a reference to the document in the table around whatever data type you have. Hence, you might find something like a `Selection<Array>`, meaning an array you can `.update` and `.delete`.

### From `Selection<Stream>` To Stream

Our query has taken us from table, to table slice, to `Selection<Stream>` and has left us with all northbound trains with a number between 300 to 400, ordered by their train number. From all those trains, we actually only want trains that pass through the 22nd Street station (identified by the slug `22nd-street`). In order to do that, we will use the [`.hasFields`](http://rethinkdb.com/api/javascript/has_fields/) method. Also, we only need two properties from this query: `number` and `stations` (an object with all the stations the trains stop at). In order to do that, we are going to `.pluck` these properties from each document.

```javascript
r.db('caltrain').table('trains')
 .between(300, 400, {'index': 'number'})
 .orderBy({'index': 'number'})
 .filter({'direction': 'north'})
 .hasFields({'stations': {'22nd-street': true}})
 .pluck('number', 'stations')
 // .typeOf() "STREAM"
```

This will return a result of type 'stream'. How is this different from `Selection<Stream>`? Because we have plucked these two properties from the query, we have now lost the reference to the original document in the database and the ability execute actions that reference that document. Streams are basically a collection of documents in which the results are loaded lazily, meaning that not all documents have been loaded into memory. This seemingly minute distinction is important for when we add a new line to our query.

### From Stream To Array

We now have a transformed stream of the documents that we need. For the last part of this query, we're going to sort these documents by the time at which they depart from the 22nd Street station in San Francisco. 

```javascript
r.db('caltrain').table('trains')
 .between(300, 400, {'index': 'number'})
 .orderBy({'index': 'number'})
 .filter({'direction': 'north'})
 .pluck('number', 'stations')
 .hasFields({'stations': {'22nd-street': true}})
 .orderBy('stations', '22nd-street')
 // .typeOf() "ARRAY" 
```

Invoking this method will return an array. The reason for this is that `(stations)('22nd-street')` is not an index, so the database needs to load all documents into memory in order to sort them. Since all documents are already stored in memory, the query will return all documents and not a stream of documents.

### Final Thoughts

And that's our query! We've gone through all of RethinkDB's sequence types and explained the differences between them. RethinkDB's different data types might seem a bit complicated at times, but once you understand them, ReQL becomes that much more logical, powerful and flexible. These data types provide a glimpse into the inner workings of the database. They let you know what the effects of different parts of your query are and how different methods are tied to different kinds of data. 

If you still haven't played around with RethinDB and you're reading the bottom of this article, that's probably a sign that you should [go ahead and install it](http://rethinkdb.com/install). After that, [download the data set](http://thejsj.com/2015/caltrain-data/caltrain-rethinkdb-dump.tar.gz) to run some of these queries! You can also [follow RethintkDB on Twitter](https://twitter.com/rethinkdb) or take a peek at our [IRC channel](irc://chat.freenode.net/#rethinkdb).
