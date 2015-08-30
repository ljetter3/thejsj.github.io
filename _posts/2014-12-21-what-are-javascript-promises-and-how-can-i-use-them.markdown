---
layout: post
title: What Are JavaScript Promises And How Can I Use Them?
date: 2014-12-21 18:51:36.000000000 -08:00
---
Usually, when writing JavaScript asynchronous code and you want something to happen _after_ something else, you pass in a function into another function. This is what's usually called a callback function. But, you already knew that, right?

Callbacks are great. They're one of those things that make JavaScript beautiful. But, in excess, callbacks lead to code that looks like this:

```javascript
doSomethingAsynchronous(function () {
  doSomethingAsynchronousAgain(function () {
    doSomethingAsynchronousYetAgain(function () {
      // We're done!
    });
  });
});
```

This code unorganized, confusing, and difficult to read. This is what, in the JavaScript universe, is usually refered to as 'callback hell'. Personally, I would never write code this way. I'd write it this way:

```javascript
var doSomethingAsynchronousAgainHandler = function (cb) {
    doSomethingAsynchronousYetAgain();
};
doSomethingAsynchronous(doSomethingAsynchronousAgainHandler);
```

Basically, I would write handler functions for several things that would live outside the callback and would remove the crazy nesting.

Yet, there's something to be said about the fact that callbacks are inherently different from any other type of argument. Callbacks define the flow and logic of your application. They're not needed inside the context of your function, since your function doesn't _need_ this callback to work. Rather, the function just needs to notify us when it has been resolved.

Wouldn't it be nice if there was a way cleary state the behavior of our asynchronous code?

### What Are Promises?
This is exactly what promises aim to fix! Promises are a way to interact with asynchronous events. Actually, [Parse's blog](http://blog.parse.com/2013/01/29/whats-so-great-about-javascript-promises/) gives a pretty nice explanation.

> At its core, a Promise represents the result of a task, which may or may not have completed. The only interface requirement of a Promise is having a function called then, which can be given callbacks to be called when the promise is fulfilled or has failed.

This seems pretty abstract. Let's look at an example.

`$.ajax` With Callbacks
Disclaimer: jQuery promises are [messed up](https://github.com/jquery/jquery/commit/a41f2406748e3113751ab1e5b5d990d9144123fc). They're not [Promises/A](http://wiki.commonjs.org/wiki/Promises/A) compliant and have some weird behavior, but they API I'll use in this post is the same as Promises/A.

When you make an [AJAX request in jQuery](http://api.jquery.com/category/ajax/), you can pass the AJAX request a `.success` property. That `.success` property is just a function that will get executed if the HTTP request is successful.

```javascript
$.ajax({
  url: "http://fiddle.jshell.net",
  success: function (data) {
    console.log(data.slice( 0, 100 ));
  }
});
```

[Run in JSFiddle](http://jsfiddle.net/thejsj/7kxv56tw/)

If we wanted to chain three AJAX requests, our code would look something like this:

```javascript
// Anti-pattern: Don't do this
$.ajax({ // Don't do this
  url: "http://fiddle.jshell.net", // Don't do this
  success: function (data) { // Don't do this
    console.log('First Response:', data.slice(0, 10));
    $.ajax({ // Don't do this
      url: "http://fiddle.jshell.net/favicon.png",
      success: function (data) { // Don't do this
        console.log('Second Response:', data.slice(0, 10));
        $.ajax({ // Don't do this
          url: "http://fiddle.jshell.net", // Don't do this
          success: function (data) { // Don't do this
            console.log('Third Response:', data.slice(0, 10));
          }
        });
      }
    });
  }
});
// I'm serious! Don't do this!
```

[Run in JSFiddle](http://jsfiddle.net/thejsj/7kxv56tw/2/)

WOW!!! IS THAT CODE UGLY OR AM I BLIND! Oh, and we haven't even written any error handling! Don't worry I'll save you from the despair. Just go ahead and imagine twice the code and a slow, painful dive into callback hell.

![Highway to Callback Hell](/assets/images/2014/12/callback-hell.jpeg)

This is one of the biggest problems promises aim to solve.

### `$.ajax` With Promises

A promise has a `then` method that you can call on any function. In jQuery, this would look something like this:

```javascript
$.ajax({
  url: "http://fiddle.jshell.net",
})
.then(function(data) {
  console.log( "Sample of data:", data.slice( 0, 100 ) );
})
```

Notice how our callback function is **NOT** a property of the object we pass to our AJAX function. It is a method of the that function. The reason why this works is that `$.ajax` returns a **promise**.

The advantage of promises is that promises return promises. This is so important I'm going to repeat it again. Promises return promises. This is so important that I'm going to quote myself.

> Promises return promises.

![Promsies return promises](http://i1.kym-cdn.com/entries/icons/original/000/009/993/tumblr_m0wb2xz9Yh1r08e3p.jpg)

Why is this so important? Let's take a look at our AJAX function with promises.

```javascript
$.ajax({
  url: "http://fiddle.jshell.net",
})
.then(function(data) {
  console.log("First Response:", data.slice( 0, 10));
  return $.ajax({
    url: "http://fiddle.jshell.net/favicon.png",
  });
})
.then(function (data) {
  console.log("Second Response:", data.slice( 0, 10));
  return $.ajax({
    url: "http://fiddle.jshell.net",
  });
})
.then(function(data) {
  console.log("Third Response:", data.slice( 0, 10));
});
```

[Run in JSFiddle](http://jsfiddle.net/thejsj/wtsosgsj/1/)

Every `$.ajax` request returns a promise whith a `.then` method for its callback. After the first callback is resolved, `.then` returns another AJAX request, which is also a promise. Now we can chain multiple `.then` statements together, even though all functions are asynchronous.

Implementing errors is now much simpler. We just add a `.fail` method at the end of our `$.ajax` request and our error will cascade down to our `.fail` method. Keep in mind that in Promises/A compliant implementatiosn you would typically use the `.catch` method.

```javascript
$.ajax({
  // Return an error ON PURPOSE
  url: "http://thejsj.com",
})
// ... see above... //
.fail(function (err){
  console.log('Promise Error:');
  console.log(err);
});
```

[Run in JSFiddle](http://jsfiddle.net/thejsj/wtsosgsj/2/)

![Error Image in JSFiddle](/assets/images/2014/12/JavaScript-Promises-Error.png)

Congratulations, now you know how promises work! I hope you can see how they're useful and they're a great way to code asynchronous code. If you're interested in using promises in your own code, I'd recommend using [q](https://github.com/kriskowal/q), [bluebird](https://github.com/petkaantonov/bluebird), or [when.js](https://github.com/cujojs/when)
