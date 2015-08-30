---
layout: post
title: Sample Data for RethinkDB
date: 2015-05-27 11:10:04.000000000 -07:00
---
Often times, people who are new to RethinkDB want to play around with the database but don't have a data in mind to use it with. Because of this, I went ahead and made [a repository with some small data sets taken from Wikipedia](https://github.com/thejsj/sample-data).

![](/assets/images/2015/05/sample-data.png)

Now, anyone can (without cloning the repo) go ahead and run this command in their data explorer and instantly have some data to play with: 

```javascript
r.tableCreate('countries')
r.table('countries')
 .insert(r.json(r.http('https://raw.githubusercontent.com/thejsj/sample-data/master/data/countries.json')))
```
This command will add a table called `countries` with all the countries in the world, taken from [this Wikipedia article](http://en.wikipedia.org/wiki/List_of_countries_and_dependencies_by_population).

The result looks something like this:

![](/assets/images/2015/05/data-explorer-countries.png)

These datasets are very small and don't have a lot of entries, but they're a good way to start playing around with RethinkDB. There are also entries for [Oscar winning films](https://github.com/thejsj/sample-data/blob/master/data/oscar-winning-films.json) and [the world's most populated urban areas](https://github.com/thejsj/sample-data/blob/master/data/urban-areas.json), but there might be more added in the future.

If you install RethinkDB (and play around with this data), go ahead and look at the [installation instructions on the RethinkDB webiste](rethinkdb.com/install).
