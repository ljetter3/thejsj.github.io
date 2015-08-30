---
layout: post
title: The most important tradeoff when modeling data in RethinkDB
date: 2015-06-26 14:30:51.000000000 -07:00
---
A question many RethinkDB users commonly have is: "How do I model my data?". Because RethinkDB is a NoSQL document store with no schema enforcement but with joins, people get a bit confused about how to structure their data. Should it be more like MongoDB or should it be more like SQL? How is data modeling in RethinkDB different form other databases? Is what I know now still useful? Data modeling in RethinkDB is so flexible that it can be a little overwhelming to decide how to structure your data, and it's young enough that there aren't a lot of battle tested best-practices out there. But, a lot of already established principles for data modeling are perfectly applicable in RethinkDB.

In this blog post, I'll talk about the most important trade-off when modeling your data for RethinkDB. Because RethinkDB has joins and also has support for nested documents, the trade-off goes as follows: 

> Do I store this in a subdocument I do I store it in another table and join it?

In order to understand this trade-off more accurately,  let's see how data modeling works in other databases.

## Data modeling in SQL

In SQL, all data should be normalized into a couple of very basic data types: strings (varchar, text), numbers (integer, bigint, decimal) and date/time objects (date, time, timestamp). More complex data is modeled through relations, where a field in a row references another row.

As an example, let's think of a family. This (quite famous) family has three members: 

```
Family
+----+-------+
| id | name  |
+----+-------+
|  1 | Darth |
|  2 | Luke  |
|  3 | Leia  |
+----+-------+
```
We not only want to store the members of this family, but also the relationships between the people in this family. For that, we have another table with the relationships between these individuals.

```
Relationhips (Closure Table)
+----------+------------+
| ancestor | descendant |
+----------+------------+
|        1 |          1 |
|        2 |          2 |
|        3 |          3 |
|        1 |          2 |
|        1 |          3 |
+----------+------------+
```
The integers in our relationships table refer to the `id`s of the rows in our family table. When queried, this data is then joined from the separate tables. This is a very basic example of how data is modeled in relational databases.

## Data Modeling in MongoDB

In MongoDB, you can store JSON documents. The interesting part about this is that you can basically store any document inside another document through an object or through an array. In theory, you could store the whole database in a single document (which is terrible idea, but theoretically possible). Because of MongoDB's lack of support for joins and the incredible flexibility of JSON documents, there's an incentive to store everything in the same document through subdocuments. This would look something like this:

```javascript
{
  "id": 1,
  "name": "Darth", 
  "children": [ 
    { "name": "Luke" },
    { "name": "Leia" } 
    ]
}, {
  "id": 2,
  "name": "Luke"
}, {
  "id": 3,
  "name": "Leia",
}
```

You could also save the ids in an array and join these documents together, but, in MongoDB, this has to be done at the application level. 

This would look something like this:

```json
{
  "id": 1,
  "name": "Darth", 
  "children": [ 2, 3 ] 
}, {
  "id": 2,
  "name": "Luke"
}, {
  "id": 3,
  "name": "Leia",
}
```

Finally, you can also model your data in the same way as with a SQL database, but this would be cumbersome since it would require a lot of application logic. Also, intersection tables start to seem awkward when you can just store elements as an array of ids. 

## Data Modeling in RethinkDB

In RethinkDB, any of these approaches are valid. Joins let you store data in different tables and join them at the database level, while subdocuments allow you to store complex data in a single document. It's important to point out that, while RethinkDB supports joins, it doesn't support foreign keys and cascading queries, which is an important part of SQL's relational model. Regardless, this is where the main trade-off in modeling data for RethinkDB comes in. If I have two pieces of data that relate to each other (family members and the relationships between these family members), should I store those relationships as a subdocument or should I store them in another table? Both options are equally valid. Whenever you start modeling your data, this is probably the most important question you should be asking yourself.

## Considerations

We've now explained a couple of different ways in which to model your data, but why exactly would I pick one approach over another? In this section I'll explore 3 things to consider when modeling your data: 

#### 1. How are you querying your data?

How you're querying your data is one of the biggest things to consider when deciding if you want to split data into different tables or keep it in the same document. If you're querying both types of data separately, for different purposes, it's better to store these two pieces of data separately. 

For example, if I have a collection of states and cities and every time I look up a city, I also lookup the city it belongs to, it's more efficient to store the city inside of the state as a subdocument.

```javascript
{ 
  "id": 1, 
  "name": "California",
    "cities": [
      { "name": "San Francisco" },
      { "name": "Mountain View" }
    ]
}, {
  "id": 2, 
  "name": "Oregon",
  "cities": [
    { "name": "Portland" },
    { "name": "Salem" }
  ]
} 
```

If, on the other hand, I often write queries for all the cities and I don't really need the state of that city, it's probably better to keep both city and state separated in two different tables.

```javascript
// States
{ 
  "id": 1, 
  "name": "California",
  "cities": [ 3, 4] 
}, {
  "id": 2, 
  "name": "Oregon",
  "cities": [ 1, 2 ]
}

// Cities
{ "id": 1, "name": "Portland" },
{ "id": 2, "name": "Salem" },
{ "id": 3, "name": "San Francisco" },
{ "id": 4, "name": "Mountain View" }
```

If I ever need to query the state for that particular city, I can then create a [multi index](http://rethinkdb.com/docs/secondary-indexes/javascript/#multi-indexes) in my `cities` field, and query the state where that city is, using the city's id.

#### 2. What is your read vs write/update load?

How much data you write/update vs how much data you read is also something you should consider when modeling your data and structuring your database. If, in your application, you are executing a lot of writes or updates, it's better to split document into different tables, instead of having larger documents with a lot of subdocuments. This is more performant, because it's easier to write one smaller document to disk than to read and then update a larger document.

If, for example, I was constantly updating a property in any of the cities in my database, it would be really expensive to read the document for the state (with potentially thousands of cities), change a particular property in the city, and then re-write it to the database through an update. It's much more performant to update a smaller document for the city. 

On the other hand, if I was reading through all the cities in a state, it would be more performant to keep all cities in a subdocument, since the database would only need to read one document and wouldn't have to join a document from another table.

#### 3. Do you need Atomic updates?

Because of RethinkDB's distributed nature, RethinkDB can only guarantee atomic updates on a single document. If a query operates on 10 documents, it can guarantee the the full update on a single document will be atomic, but it can't guarantee that all 10 updates will succeed or fail. So, if you need atomic updates, you need to keep that data in a single document. 

## Final Thoughts

While RethinkDB is incredibly flexible and doesn't enforce a schema on your database, you still need to think about your data and how to structure your data. There's no escaping that. Once you've thought about your data, your requirements, and how you'll interact with your data, RethinkDB's flexibility is a great asset.
