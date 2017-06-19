---
layout: post
title: Handling Errors with ES6
date: 2016-08-02 00:00:00 -07:00
---

_This post is a re-post of my blog post in the [Runnable Blog](http://runnable.com/blog), as part of my work for [Runnable](http://www.runnable.com). [Check out the original post](https://runnable.com/blog/handling-errors-with-es6)._

Over the last couple of months, we’ve transitioned away from callback-style error handling. Instead, we’re handling our errors with ES6 features (mainly promises and classes). In this post, I’ll talk about why we’ve made this transition.

### The Old Way

One of the most common criticisms of JavaScript, and probably more specifically of Node.js, is the way in which errors are handled through callbacks. The pattern goes something like this:

```
var myFunc = function (cb) {
  doSomething(function (err, a) {
    if (err) return cb(err)
    doSomethingElse(function (err, b) {
      if (err) return cb(err)
      return cb(null, [a, b])
    })
  })
}
```

Obviously, there are better ways of handling errors such as breaking these up into separate functions or using a library like [async](https://www.npmjs.com/package/async) to improve callback flow. But for the most part, JavaScript callbacks require that you always handle any errors immediately.

What’s good about this pattern is that it forces developers to handle errors. As the person writing the code, you always want to make sure you know when an operation can fail, especially if it’s an asynchronous operation.

In practice though, this is not actually how we’re writing programs. A quick look through some of our repositories shows that most `if (err)` statements are just passing the error to the callback with some sort of basic logging. This might seem like a lazy way of writing code, but in most of our cases, the whole operation will fail if part of it fails. Some exceptions to this are retry logic, reverting changes, and advanced error reporting.

When we actually want to handle a specific type of error, we often revert to some kind of [duck typing](https://en.wikipedia.org/wiki/Duck_typing) where we match the error message:

```
var myFunc = function (cb, retries) {
  databaseQuery(function (err, a) {
    if (err.message.match(/socket.*hang.*up/i) {
      if ((retries || 0) < 10) {
        return myFunc(cb, (retries || 0) + 1)
      }
      return cb(err)
    }
    return cb(null, a)
  })
}
```

This pattern is effective, but it’s not particularly elegant or easy to understand.

### A New Pattern

Promises give us a cleaner way to handle errors. Instead of having to handle errors for every single operation, we can clean up this code by doing it at the end of multiple operations.

```
const myFunc = function () {
  return doSomething()
    .then(a => {
      return Promise.all([a, doSomethingelse()])
    })
}
```

As you can see, there is no error handling here. If the person writing this code wanted to handle an error, they would have to add a `.catch` at the end of the function declaration.

For most implementations where you only want to throw the original error to the function caller, this works well, but it’s obviously not enough for every case. If, for example, we want to log all errors in a particular function, we can do the following:

```
const myFunc = function () => {
  return doSomething() // we could also just return this promise
    .then(a => {
      return Promise.all([a, doSomethingelse()])
    })
    .catch(err => {
      log.error({ err: err }, 'Unexpected Error')
      throw err // Make sure cb gets the error
    })
}
```
If we wanted to add some retry logic to this function and we knew the specific type of error we would get, we can use [Bluebird](https://www.npmjs.com/package/bluebird) to match only that type of error:

```
const Promise = require('bluebird')

const myFunc = function (retries) => {
  return doSomething()
    .then(a => {
      return Promise.all([a, doSomethingelse()])
    })
    .catch(SocketHangupError, err => { // Handle this error in a different way
      return myFunc(cb, (retries || 0) + 1) // Retry
    })
    .catch(err => {
      log.error({ err: err }, 'Unexpected Error')
      throw err // Make sure cb gets the error
    })
}
```

If one of our functions just threw a generic `Error`, we could write a custom error in order to match it correctly.

```
const Promise = require('bluebird')
class SocketHangupError extends Error {}

const _doSomethingelse = () => {
  return _doSomethingelse()
    .catch(err => {
      if (err.message.match(/socket.*hang.*up/i) {
        throw SocketHangupError(err.message)
      }
      throw err
    })
}

const myFunc = (cb, retries) => {
  doSomething()
    .then(a => {
      return Promise.all([a, _doSomethingelse()])
    })
    .catch(SocketHangupError, err => {
      return myFunc(cb, (retries || 0) + 1)
    })
    // ...
    .asCallback(cb)
}
```

### Writing an HTTP router with ES6 error handling

We prefer this pattern because it allows us to separate error handling from the main logic of our code, leaving it more elegant and concise.

A good example of a place where this is really useful is writing a common HTTP error handler for many promise-based routes. In the following scenario, we have two HTTP routes that are just basic CRUD operations over our database:

```
class Router {

  constructor() {
    const app = express()
    // Load Routes
    app.get('/user', Router.get)
    app.patch('/user', Router.patch)
    app.listen(3000)
  }

  static get (req, res) {
    let query = User.forge().format(validatedReq.query)
    return User.collection(validatedReq.query)
      .query({ where: query }).fetch()
      .then(users => res.json(users.toJSON()))
  }

  static patch (req, res) {
    return User.fetchById(req.params.id)
      .then(org => org.save(validatedReq.body))
      .then(org => org.toJSON())
      .then(org => res.json(org))
  }
}
```

Instead of handling all errors independently, we want to handle all errors in one single function that we pass to all routes. For that, we can use custom errors.

```
const Promise = require('bluebird')

const httpErrorHandler = (err, res) => {
  return Promise.reject(err)
    .catch(NotFoundError, () => {
      return res.status(404).send('Not found')
    })
    .catch(ValidationError, () => {
      return res.status(400).send('Bad Request')
    })
    .catch(() => {
      return res.status(500).send('Internal Server Error')
    })
}
```
Now, we can use this error handler in our routes to have a single global error handler, so all error handling logic will live in the same place.

```
// ...
  static get (req, res) {
      // ...
      .then(users => res.json(users.toJSON()))
      .catch(err => httpErrorHandler(err, res))
  }

  static patch (req, res) {
      // ...
      .then(org => res.json(org))
      .catch(err => httpErrorHandler(err, res))
  }
// ...
```

### Conclusion

Not all types of programs require this type of error validation, but many types of applications can really benefit from this pattern. Here at Runnable, we’ve successfully used this pattern for everything from HTTP routes and workers to database calls. In the process, we’ve been been able to not only clean up our code, but actually improve the way we do error handling.

