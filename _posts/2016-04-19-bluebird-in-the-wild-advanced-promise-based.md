---
layout: post
title: Bluebird in the wild. Advanced promise-based workflows
date: 2016-04-19 00:00:00 -07:00
---

_This post is a re-post of my blog post in the [Runnable Blog](http://runnable.com/blog), as part of my work for [Runnable](http://www.runnable.com). [Check out the original post](https://runnable.com/blog/bluebird-in-the-wild-advanced-promise-based)._

Over the last months, we've been converting our code from using callbacks to using promises. In our coding style, we've found promises to be a cleaner way to organize code and a better way to deal with error handling. As we've done more and more of this, we've gotten better at identifying effective patterns for using promises and the best ways to migrate to them. We've also found Bluebird to be the best promise library out there. Bluebird not only provides solid performance, but it also provides wonderful abstractions over promises.

In this article, I'll show you some of the more useful methods in Bluebird and how we use these here at Runnable. Some of these are taken directly from our codebase in order to help out anyone looking to start migrating to promises or just improve and clean up your current implementations.

Quick Note: I'm presuming you're already familiar with callbacks and promises so I won't go into what they are and the basics of using promises. If you're not familiar with promises, you should check out MDN's entry for Promises.

### `Promise.promisify` and `Promise.promisifyAll`

The first two methods I want to point out are `Promise.promisify` and `Promise.promisifyAll`. `Promise.promisify` takes a function that takes a callback as its last argument and converts it into a function that returns a promise (without the need for a callback). `Promise.promisifyAll` does the same for all function properties in an object by adding a new function with `Async` appended to the name of the original function (e.g. `readFile` becomes `readFileAsync`).

This method is really useful for libraries which use callbacks, but you want to convert to use promises. You can require the library and pass it into `Promise.promisifyAll` to quickly integrate it into your project. This method can also be use to quickly migrate your old callback-based code into promises. Currently, we use these on most of our Mongoose models and some our dependencies that don't use promises such as `request` and `dockerode`.

```
// Before:
const fs = require('fs')

fs.readFile('./helloWorld', (err, fileContents) => {
  if (err) return errorHandler(err)
  console.log(fileContents)
})
// After:
const Promise = require('bluebird')
const fs = Promise.promisifyAll(require('fs'))

fs.readFileAsync('./helloWorld')
  .then(fileContents => console.log(fileContents))
  .catch(errorHandler)
```

### `Promise.fromCallback` and `Promise.asCallback`

Most times, promisifying functions will get you close enough to being able to use promises, but not every time. Sometimes, you might still want to interact with a function through a callback, but might not want to or be able to promisify it. For that, there's `Promise.fromCallback`. This method provides a callback you can pass to any other function and it will return a promise. This is much cleaner than having to interact with `resolve` and `reject` functions.

```
// Before:
const Promise = require('bluebird')
const User = require('./models/user')

return new Promise((resolve, reject) => {
  User.findById(ID, (err, user) => {
    if (err) {
      return reject(err)
    }
    return resolve(user)
  })
})
  .then(user => console.log(user))
// After:
const Promise = require('bluebird')
const User = require('./models/user')

return Promise.fromCallback((cb) => {
  User.findById(ID, cb)
})
  .then(user => console.log(user))
```

On the other hand, you might have functions that take a callback as an argument but you still want to write using promises. For that, there's `Promise.asCallback`. With `Promise.asCallback` you can have a normal promise chain and then just pass the callback into `.asCallback`. One of the ways we use this if for asynchronous tests. We usually write a test with a promise chain and then just pass our `done` function to `asCallback`.

```
// Before:
const Promise = require('bluebird')
const fs = Promise.promisifyAll(require('fs'))

it('should read a file', (done) => {
  fs.readFileAsync('./fileAsync')
    .then(contents => {
      expect(contents).to.match(/hello.*world/)
      return done()
    })
    .catch(done)
})
// After:
const Promise = require('bluebird')
const fs = Promise.promisifyAll(require('fs'))

it('should read a file', (done) => {
  fs.readFileAsync('./fileAsync')
    .then(contents => {
      expect(contents).to.match(/hello.*world/)
    })
    .asCallback(done)
})
```

### Passing error types into catch

Another really useful utility provided by Bluebird is the ability to pass an error constructor/class as the first argument to `catch` in order to only handle that type of error. We mostly use this feature by creating our own errors classes in our code and throwing them appropriately. Then our `catch` statement is able to filter out the error we've thrown and handles it accordingly.

```
// Before:
const Promise = require('bluebird')
const fs = Promise.promisifyAll(require('fs'))
class FileNotFoundError extends Error {}

fs.readFileAsync('./fileAsync')
  .then(contents => {
    if (!contents) throw FileNotFoundError()
    expect(contents).to.match(/hello.*world/)
  })
  .catch((err) => {
    if (err instanceof FileNotFoundError) {
      return false
    }
    throw err
  })
// After:
const Promise = require('bluebird')
const fs = Promise.promisifyAll(require('fs'))
class FileNotFoundError extends Error {}

fs.readFileAsync('./fileAsync')
  .then(contents => {
    if (!contents) throw FileNotFoundError()
    expect(contents).to.match(/hello.*world/)
  })
  .catch(FileNotFoundError, () => {
    return false
  })
```

### `Promise.method` and `Promise.try`

One of the nice things about promises is that we can throw errors in a synchronous manner. One example of this (and a very good practice in general) is starting a function with some input validation. If the provided inputs don't meet our validation, we want to throw an error explaining to the consumer of the function what we expect. When doing this with promises, we need to wrap that logic around a promise in order for the error to be properly caught. `Promise.try` is a great way to deal with this. Instead of having to create an empty promise, we can just pass a function to `try` that will return a promise and catch errors inside the promise flow.

```
// Before:
const Promise = require('bluebird')

var method = function (input) {
  return Promise.resolve()
    .then() => {
      if (!input) throw new Error('Hello World')
    })
}
// After:
const Promise = require('bluebird')

var method = function (input) {
  return Promise.try(() => {
    if (!input) throw new Error('Hello World')
  })
}
```

`Promise.method` takes this idea one step further. With `Promise.method`, we can just pass any function into it, in order to have it always return a promise. The effect is similar to wrapping your function around a `Promise.try`. In our code base we use `Promise.method` to declare functions which we want to always return a promise.

```
// Before:
const Promise = require('bluebird')

var method = function (input) {
  return Promise.try(() => {
    if (!input) throw new Error('Hello World')
  })
}
// After:
const Promise = require('bluebird')

var method = Promise.method(() => {
  if (!input) throw new Error('Hello World')
})
```

There is an important thing to note here. If a function invoked by a promise throws an error asynchronously, that error will not be caught by the promise. The error will throw outside the promise chain error and the process will exit if not inside a try/catch or a domain. Basically, you have to be careful that all the asynchronous code you use is written using promises or ensure callbacks are properly handled.

```
'use strict'
const Promise = require('bluebird')

let cb = () => setTimeout(() => { throw new Error() }, 0)
let justDoIt = Promise.method((num) => {
  return cb()
});

justDoIt()
  .catch((err) => {
    // This line won't run :(
    console.log('Caught Error', err)
  })
```

### `Promise.race` and `Promise.any`

`Promise.race` and `Promise.any` are similar in that they both take an array of values/promises and return the first one to be fulfilled. The main difference between these is that `Promise.race` returns the first resolved or rejected promise, while `Promise.any` returns the first fulfilled promise. In our codebase we use these methods in a couple of ways.

The first one is testing. Some of our tests have to create socket connections and send messages over that connection, expecting something back. As a way to timeout the requests, we pass an array with our promise and a delay promise to ensure it doesn't timeout. Keep in mind that we use `race` here because we want to the promise to be rejected if our socket connection throws an error.

```
const Promise = require('bluebird')

it('should create a connection', () => {
  Promise.race([ delay(1000), getFromSocket() ])
  .then((res) => {
    expect(res).to.not.be('undefined');
  })
  .asCallback(done)
})
```

The second interesting use case is for simultaneously checking for multiple conditions. For example, we use `Promise.any` to see if a given user is the owner of X or if that user is a moderator. Here, we don't necessarily care about which one is true, just as long as one of them is.

```
const Promise = require('bluebird')
const User = require('./models/User')

var hasAccess = (container, user) => {
  return Promise.any([
    User.isModerator(user),
    User.isOwner(container, user)
  ])
    .then((user) => {
      if (!user) return false
      return document.update()
    })
}
```

### Iterables with `Promise.map`, `Promise.each`, and `Promise.filter`

Apart from all previously mentioned methods, Bluebird provides some really useful utility methods for iterables (this includes not only arrays, but also maps and sets). Some of these operations are not too different from their synchronous counterparts (`map` and `filter`), but some like `Promise.each` provide really useful abstractions that are cumbersome to write by yourself.

One of the ways in which we use `Promise.each` is for enqueuing jobs into RabbitMQ. When doing this, we don't really care about the result, and enqueuing jobs is a synchronous operation. Enqueuing a job into RabbitMQ is essentially a side effect. `Promise.each` enqueues our jobs and then returns the original array, which is really what we want (not the result of the side-effect).

```
// Before:
const Promise = require('bluebird')
const Container = require('./models/container')
const rabbitmq = require('./utils/rabbitmq-helper')

var removeByName = Promise.method((name) => {
  return Container.find({ name: name })
    .then((instances) => {
      let promise = Promise.resolve()
      instances.forEach((instance) => {
        promise = promise
          .then(() => {
            return rabbitmq.publish('container:remove', {
              id: instance._id
            })
          })
      })
      return promise
    })
})
// After:
const Promise = require('bluebird')
const Container = require('./models/container')
const rabbitmq = require('./utils/rabbitmq-helper')

var removeByName = Promise.method((name) => {
  return Container.find({ name: name })
    .each((instance) => {
      return rabbitmq.publish('container:remove', {
        id: instance._id
      })
    })
})
```

### Conclusion

Bluebird provides a much cleaner, understandable way of dealing with promises. It provides a great abstraction layer over promises, and useful methods to transition your callback-based code. If you're interested in knowing more about Bluebird and other promise workflows, check out [Bluebird’s API documentation](http://bluebirdjs.com/docs/api-reference.html).
