---
layout: post
title: New ES6 Features in Node LTS
date: 2016-11-15 00:00:00 -08:00
---

_This post is a re-post of my blog post in the [Runnable Blog](http://runnable.com/blog), as part of my work for [Runnable](http://www.runnable.com). [Check out the original post](https://runnable.com/blog/new-es6-features-in-node-lts)._

A couple of weeks ago, Node.js released its latest LTS: version 6.9.0. I realized this was the case because one of our services broke. It used the `nodejs:lts` image and got upgraded by mistake. Inspired by this breaking of one of our services, I decided to dig into what was new in this version of Node. In this blog post, I’ll walk you through some of the new ES6 additions to Node and how they will change the code you write.

### Argument Destructuring
The first ES6 feature I’ll talk about is argument destructuring. With argument destructuring you can select specific properties out of an object or an array. This helps in making code a lot less verbose, especially when getting arguments for a function. For example, if I have a function that takes an object, but I don’t want to reference that object throughout my function, I can just do this:

```
// Before
function hello (opts) {
  let firstName = opts.firstName
  let lastName = opts.lastName
  let age = opts.age
  console.log('Hello ${firstName} ${lastName}. Glad you’re feeling ${age}')
}
hello({ firstName: 'Taylor', lastName: 'Swift', age: 22 })

// After
function hello (opts) {
  let { firstName, lastName, age } = opts
  console.log('Hello ${firstName} ${lastName}. Glad you’re feeling ${age}')
}
hello({ firstName: 'Taylor', lastName: 'Swift', age: 22 })
```

Basically, you can assign the value of the properties in an object to a specific variable. The advantages of doing this is that you’re able to declare a schema into the properties of an object (or an array) without needing a line for every single declaration. Extracting properties into their own variables inside a function is generally a good idea because it allows your editor and linters to know more about your program. Linters like `standard` can tell you if a variable is not declared anywhere, but it can’t tell you if an object property is declared or not.

This syntax can also be used inside function declarations, where the object can be passed to the top of the function.

```
function hello ({ firstName, lastName, age }) {
  console.log('Hello ${firstName} ${lastName}. Glad you’re feeling ${age}')
}
hello({ firstName: 'Taylor', lastName: 'Swift', age: 22 }) // Hello Taylor Swift. Glad you’re feeling 22
```

### Destructruing Gotchas

There is one very important gotcha with this feature. Because JavaScript is dynamically typed, the type of the passed value might not be an object. For this reason, the variable cannot be destructured. In this case, JavaScript will throw a run-time `TypeError`. This is something that needs to be taken into consideration when writing such code.

```
function hello (opts) {
  let { firstName, lastName, age } = opts
  console.log('Hello ${firstName} ${lastName}. Glad you’re feeling ${age}')
}
// Throw the following error
/**
 * TypeError: Cannot match against 'undefined' or 'null'.
 */
hello(undefined) // or any other value that’s not an object
```

Interestingly enough, JavaScript actually does the right thing with `null` by throwing the `TypeError` even though `null` is technically an object (`typeof null`). However, it treats arrays as objects, which is usually not what you would want. An interesting thing about ES6 is that an iterator can be declared for any object. This would allow the use of things like array destructuring and the use of `for of`.

### Default Parameters

On top of this destructuring, there’s also the ability to add defaults to these function parameters and assignment destructuring. If any of these default variables are `undefined` (and only if they’re `undefined`!) the value of that property will be switched to whatever the default property value is.

```
// Before
function hello (opts) {
  opts = (opts === undefined ? {} : undefined)
  let firstName = (opts.firstName === undefined ? "Jorge" : opts.firstName)
  let lastName = (opts.lastName === undefined ? "Silva" : opts.lastName)
  let age = (opts.age === undefined ? 89 : opts.age)
  console.log('Hello ${firstName} ${lastName}. Glad you’re feeling ${age}')
}
hello() // Hello Jorge Silva. Glad you’re feeling 89

// After
function hello ({ firstName = "Jorge", lastName = "Silva", age = 89 } = {}) {
  console.log('Hello ${firstName} ${lastName}. Glad you’re feeling ${age}')
}
hello() // Hello Jorge Silva. Glad you’re feeling 89
```

Default parameters are a good way to handle the issue of destructuring assignments throwing type errors when the destructuring does not match. Still, this will only work when the value of that property is `undefined`.

### Rest Parameters

Another interesting ES6 features is rest parameters. With rest parameters, you can take all the arguments passed to a function (for example) and join them together into a new array with all values. Rest parameters save us from having to write the verbose logic to have to turn the `arguments` variable into a real array.

```
// Before
function sum () {
  // Convert `arguments` into an an actual array
  var args = Array.prototype.slice.call(arguments)
  return args.reduce((a, b) => a + b, 0)
}

// After
function sum (...args) {
  return args.reduce((a, b) => a + b, 0)
}
```

Rest parameters can also be used with restructuring to get only the first n arguments for a function and get all other arguments as a rest parameter. For example, if making a function that takes the name of some action and executes an operation on all the passed numbers to that function. This might not be the best way to write this function but it shows how this new syntax can be used in conjunction.

```
function sum (...[action = 'sum', ...nums]) {
  if (action == 'sum') return args.reduce((a, b) => a + b, 0)
  if (action === 'multiply') return args.reduce((a, b) => a * b, 1)
  throw new Error('Invalid action passed')
}
```

### Array.includes

One of my favorite functions in the new version of Node is `Array.includes`. This function is basically a shortcut for `arr.indexOf() !== -1`, but it is a very, very nice shortcut to have. I particularly remember this function because it’s so simple, yet it never made it to Node until now.

```
// Before
function doesValueExist(arr, value) {
  return args.indexOf(value) !== -1 // What does that even mean!
}

// After
function doesValueExist(arr, value) {
  return args.includes(value)
}
```

### Unhandled Promises
One thing that has a lot of people in the Node.js community very happy is support for unhandled promises at a process level. On any process, you can add a `process.on('warning')` to handle any promises that throw any errors not caught by the promise chain.

```
'use strict'

Promise.resolve()
  .then(() => {
    throw new Error('!!!!')
  })

process.on('warning', err => {
  // This would log the following
  /**
   * (node:18876) UnhandledPromiseRejectionWarning: Unhandled promise rejection (rejection id: 1): Error: !!!!
   * { UnhandledPromiseRejectionWarning: Unhandled promise rejection (rejection id: 1): Error: !!!!
   */
  console.log(err)
})
```

This process level handler can be used for logging purposes and reporting. Any error thrown by this handler can be sent to [Rollbar](https://rollbar.com/) for alerting. The only problem I’ve noticed with this is that stack traces are not very good, which might make it very hard to trace back where the unhandled error comes from.

### Conclusion

The new ES6 features in Node v6.9.0 will really change how we write JavaScript on the server. A lot of these features will really help in bringing down the amount of boilerplate code written around extracting values out of variables and also reducing the amount of slightly annoying parts of JavaScript.
