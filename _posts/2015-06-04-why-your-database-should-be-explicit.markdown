---
layout: post
title: Why your query language should be explicit
date: 2015-06-04 17:02:16.000000000 -07:00
---
A couple of days ago I was having a conversation with a developer about the product he's working on and his experience with [RethinkDB](http://rethinkdb.com). He caught me off-guard when he mentioned that, when writing ReQL (RethinkDB's query language), he always had a clear idea of what was going on and how the database was working as a whole. Didn't that happened will all databases he uses? He was a Postgres guy, with a lot of SQL experience, and for him Postgres was always too complex to completely understand. If you really wanted to understand something in Postgres you had to dig into the internals. With RethinkDB, he explained to me, the queries themselves exposed a lot of the logic behind how the database works. This, perhaps counterintuitively, made using RethinkDB much easier.

So, what does it mean for your query language to be explicit?

When your database query language is explicit, the way in which you interact with the database is not only simple and approachable, but also hints at the inner workings of the database. Having your query language be explicit means that you've hit at exactly the right level of abstraction: not too much, but not too little. This prevents the user from having to dig into the internals of the database in order to understand how something works. This means less time debugging and reading documentation and more time writing code.

The counterpoint to this is that you do want as many abstractions as possible. You don't want the cognitive load of having something's that more complex. You might as well write everything in assembly! Why do we need garbage collectors anyway! Obviously, the point is to have the **right** level of abstraction where things are powerful, yet simple and clear.

All this might seem a little abstract, so let's take a look at what it actually means to have an explicit database by taking a look at examining SQL and ReQL (RethinkDB's query language) queries and showing how they're different.

#### Order of Execution

In this query, we get all the users with the name 'jorge' are queried and then ordered in descending order by age.

```sql
SELECT * FROM users WHERE name = 'jorge' ORDER BY age;
```

If we wanted to dig deeper into this query, we might want to know if the "WHERE" is getting executed before the "ORDER BY". Can we tell from the query if this is the case? No, we can't. You'd have to [look it up](http://stackoverflow.com/questions/24127932/mysql-query-clause-execution-order). 

In RethinkDB, you'd write the query in the following way:

```javascript
r.table('users')
 .filter({ name: 'jorge' })
 .orderBy(r.desc('age'))
```
Now, can you tell from the query if the users are filtered or ordered first? Yes! `filter` comes first. Keep in mind that you can write the query with the `orderBy` before the `filter`, since it's up to you to decide which one you want first. Does this increase cognitive load? Yes, it does. But this is outweighed by the ability to understand how your query is being executed. 

There is a problem with this. Having an explicit order of execution lets the user write queries that are not performant. Let's say the query was inveresed:

```javascript
r.table('users')
 .orderBy(r.desc('age'))
 .filter({ name: 'jorge' })
```

This query first orders all the documents and then filters all documents with the name 'jorge'. The problem is that, the `orderBy` method now has to order many more documents than before, while the filter method has to do exactly the same amount of work. But RethinkDB won't optimize the query for you or tell you it's wrong. It'll just run it. It's up to the developer to understand what's going on and optimize accordingly. This might sound like a huge deal, but the simplicity of the language makes it easy to spot these inefficiencies and fix them accordingly.

#### Indexes

Let's say we had exactly the same query we had before: 

```sql
SELECT * FROM users WHERE name = 'jorge' ORDER BY age;
```

Can we rewrite this query in a way that will make it more efficient? Do we know if this query is using any indexes under the hood? No, not really. If we want to make this query faster, we'd need to go into the database and see if this query is using any indexes. We can do that by running the following command in our 'users' table and see what indexes the table has.

```sql
SHOW INDEXES IN users;
```

With RethinkDB, you need to explicitly set the indexes you want to use. Indexes use different operations from non-indexed operations. If we wanted to select all documents where the `name` property is equal to `jorge`, we can [create the index](http://rethinkdb.com/api/javascript/index_create/) for it and then use the `getAll` command for it, which takes a value and the name of an index. Hence, when you see a query you immediately know that it's using an index and when you see a query with `filter` you immediately know it's not using an index.

```javascript
r.table('users')
 .getAll('jorge', { index: 'name' })
 .orderBy(r.desc('age'))
```

## Final Thoughts

After a couple of months of learning RethinkDB and writing a lot of ReQL, I already feel more comfortable with it than I ever felt with any SQL database I used. Obviously, the time I've invested in it helps, but the more I think about it the more I'm convinced that RethinkDB's explicit nature makes it easier to understand and reason about your database. Not only that, but it helps you understand how databases work in general by taking away some of the magical parts.

Most developers agree that [explicit is better than implicit](https://www.python.org/dev/peps/pep-0020/), so why not have a database that is also explicit about how it executes your queries?
