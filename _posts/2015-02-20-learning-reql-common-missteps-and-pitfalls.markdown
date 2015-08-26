---
layout: post
title: 'Learning ReQL (RethinkDB''s Query Language): 5 Common Pitfalls And Rookie
  Mistakes'
date: 2015-02-20 13:07:31.000000000 -08:00
---
Over the last couple of days, I've been writing a lot of ReQL ([RethinkDB's query  language](http://rethinkdb.com/api/javascript/)). I got over the basic examples and started writing more complex queries. As I've being doing this, I noticed a couple of things that didn't work as I expected and things that took me a while to figure out. Fortunately, most of these made all the sense in the world once I started understanding the underlying principle. In this post, I want to share five issues I ran into during this process. Hopefully, this will be helpful to everyone out there starting out with RethinkDB.

### 1. Data Types: Not All Data Behaves The Same

The main thing that tripped me up, again and again, was treating everything in the same way and trying to use all methods on any type of query result. 

For example, if we had a table with cities and each document (city) contained a reference to its neighbor cities (and where they are in relation to that city) each document would look like this:
```
{
  'id': 'd9000734-078e-490b-bbfa-c11fb2f48322'
  'name': 'Mountain View',
  'state': 'CA'
  'neighbors' : {
      'a7575456-d9a5-44ad-8e0a-d3125a6da5f2' : 'east',
      'f3122d92-a0ba-4655-a51e-49a5127e9f5e' : 'west',
      '115b71e6-c40b-4ffb-ae4f-1fe923431d16' : 'south'
   }
}
```
In we wanted to count how many `neighbors` this city has, you might think we could to the following:

```
r.db('test')
 .table('cities')
 .get('d9000734-078e-490b-bbfa-c11fb2f48322')('neighbors')
 .count()
```
But that query throws an error: 
```
RqlRuntimeError: Cannot convert OBJECT to SEQUENCE in:
r.db("test").table("cities").get("d9000734-078e-490b-bbfa-c11fb2f48322")("neighbors").count()
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```
Basically, we're using a method that's meant for sequences (arrays are sequences, for example) and not for objects. In order to solve that, we can convert the object into an array by using the `.coerceTo` method or we can get all the keys in that object using the `.keys` method:

```
r.db('test')
 .table('cities')
 .get('d9000734-078e-490b-bbfa-c11fb2f48322')
 	('neighbors')
 // Convert the object into an array of tuples
 .coerceTo('array') 
 .count()
```
```
r.db('test')
 .table('cities')
 .get('d9000734-078e-490b-bbfa-c11fb2f48322')
 	('neighbors')
 // Gets all the keys in the object
 .keys() 
 .count()
```

These will both `3`, which is exactly what we want!

### 2. Operating On A Single Document VS Multiple Documents

Sometimes, when working with the results of a query, you might expect to be operating on a document's attribute, when in fact you're still referencing the collection of documents. This sounds a bit confusing, so let's look at an example.

What do you expect will be the result of this query, given the document we had above?
```
r.db('test')
 .table('cities')
 .filter({ id: '0cc569bd-5a80-4683-abbd-eb83b8bf43aa' })
 	('neighbors')
 .keys()
 .count()
```
Personally, I was expecting the result to be `3`, since there is only one document being filtered and I am selecting the `neighbors` attribute. 

After thinking about it a bit more, it wouldn't make much sense for it to return `3`, since that wouldn't be desirable if we had multiple documents. Maybe, the results would be `[3]` since that's what would result from mapping every single document. Instead, we get `1`, which is the `.count` for the number of documents in the query. When we add `(neighbors)` to the filtered documents, ReQL is effectivly mapping every document to only have the `neighbors` attribute, but still returning the `.count` for the collection of documents.

If we wanted to get `3`, we could do that two ways. We could just select the first document in the queried sequence by adding a `(0)` after `.filter`.

```
r.db('test')
 .table('cities')
 .filter({ id: '0cc569bd-5a80-4683-abbd-eb83b8bf43aa' })(0)
 	('neighbors')
 .keys()
 .count()
```
We could also just use the `.get` method to get the document directly and just call `.count` on that document's 'neighbors' attribute.

```
r.db('test')
 .table('cities')
 .get('0cc569bd-5a80-4683-abbd-eb83b8bf43aa')
 	('neighbors')
 .keys()
 .count()
```
Finally, if we wanted to return an array with the count for every document in a sequence of documents, we can just `.map` the results.

```
r.db('test').table('cities')
  .filter({ id:'d9000734-078e-490b-bbfa-c11fb2f48322' })
  .map(r.row('neighbors').keys().count())
```
Again, it's all about keeping track of what you're actually modifying when calling a method function on a query result and being aware of the different data types in your database.

### 3. Using `.filter` instead of `.get` in Changefeeds

When using `.changes`, it might make more sense to listen to changes on a document attribute by using the following query. 

```
r.db('test').table('cities')
  .get('d9000734-078e-490b-bbfa-c11fb2f48322')	
 	('neighbors')
  .changes()
```
This throw an error. The solution is not very complicated though. Just `.filter` the documents instead of getting just one document.

```
r.db('test').table('cities')
  .filter({ id: 'd9000734-078e-490b-bbfa-c11fb2f48322' })
	('neighbors')
  .changes()
```
At this point, this is only a feature that hasn't been implemented. This will probably change in an upcoming release of RethinkDB. Keep an eye out for this one!

### 4. Cursors in Changefeeds

When querying the database using ReQL in Node.js, every time `.run` is called it executes a callback or returns a promise with the result ([you do know how to use promises, right?](/what-are-javascript-promises-and-how-can-i-use-them/)):

```
r.db('test')
 .table('cities')
 .get('0cc569bd-5a80-4683-abbd-eb83b8bf43aa')('bets')
 .run(conn)
 .then(function (result) {
  // `result` is an Array of the query results
 });
```
When I first started using changefeeds, I expected my promise to also return an array with my results.
```
// DON'T COPY THIS CODE
r.db('test')
 .table('cities')
 .filter({ id: '0cc569bd-5a80-4683-abbd-eb83b8bf43aa' })
 .changes()
 .run(conn)
 .then(function (youWouldThinkThisIsAnArrayButItsNot) {
  // THIS WILL THROW AN ERROR
  youWouldThinkThisIsAnArrayButItsNot.forEach(function (row) {
      console.log(row);
    });
 });
 // DON'T COPY THIS CODE
```
Instead, I got this error:
```
err [TypeError: Object [object Feed] has no method 'forEach']
```
After reading the documentation more closely I found that my promise actually returns a cursor and not an array. (What exactly is a [cursor](http://en.wikipedia.org/wiki/Cursor_%28databases%29)? Basically, It is a way to navigate the results of query lazily.)

When the promise is resolved and the cursor is fulfilled, the promise doesn't run again. Instead, a callback is executed every-time a new change comes in. 

```
r.db('test')
 .table('cities')
 .filter({ id: '0cc569bd-5a80-4683-abbd-eb83b8bf43aa' })
 .changes()
 .run(conn)
 .then(function (cursor) {
  // This functions is called once
  cursor.each(function (error, row) {
      /** 
       * This function is called every time
       * there's a change in a row in the query
       */
      console.log(row);
    });
 });
```

### 5. Anonymous Functions in `.map` and `.reduce`

Some ReQL methods, such as `.map` and `.reduce`, take functions as arguments. For example, you can call `.map` to map documents: 

```
r.db('test')
 .table('cities')
 .map(function (row) {
  return row('population');
 });
```
First, notice that I am not using object notation (`['population']`). I'm basically calling a function on the row variable which then returns the `population` attribute.

After noticing that this is (kinda-like) JavaScript code inside the function, you might be tempted to do something like this:

```
 // DO NOT COPY THIS CODE
 ...
 .map(function (row) {
  return row('population') * 2;
 });
```
This throws an error (`TypeError: Illegal non-finite number 'NaN'.`). The reasons that it throws an error is that this operation will not be executed by JavaScript. This `.map` function is executed on the server. The `.map` function converts this code (and the complete query) into a string that is sent to and executed by the database. 

Hence, in order to multiply the result of row, we would need to use ReQL: 

```
 ...
 .map(function (row) {
  return row('population').mul(2);
 });
```

### Final Thoughts

If you've played around with RethinkDB and have run into some issues, I hope you find this useful! Honestly, the best approach to dealing with the learning curve is to open your browser in `localhost:8080` and start playing around with some queries. 

Honestly, most of the issues I encountered weren't really inconsistencies in ReQL or things that didn't make any sense. Rather, they were just cases in which my own mental model of how ReQL would work was different from how it actually worked (I call that 'learning'). Instead of getting frustrated with these issues, I mostly just got excited about changing my mental model of the database and getting to understand how it **actually** works. 
