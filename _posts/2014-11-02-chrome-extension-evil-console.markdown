---
layout: post
title: 'Chrome Extension: Evil Console'
date: 2014-11-02 08:38:13.000000000 -08:00
---
Want to mess around with your developer friends? How about a way to overwrite their console so that it misbehaves? 

Enter [Evil Console](https://chrome.google.com/webstore/detail/evil-console/hjmeopdfaoneecmmephjiacpekmgfcmi).

![Evil Console Chrome extension page](/assets/images/2015/01/Screen-Shot-2015-01-10-at-9-13-09-AM.png)

Evil console starts slowly messing around with the styling of your `console.log` messages until, at the very end, it stops showing anything at all! Wouldn't that be terribly frustrating? Exactly!

![Evil Console Screenshot](/assets/images/2015/01/Screen-Shot-2015-01-10-at-9-16-22-AM.png)

###### For Developers

If you can actually even understand what this plugin this, you're probably a developer (lucky you!). So, how does this plugin work? It's basically a thin wrapper that does 2 things: save a reference the old `console.log` and then overwrites it with a styled `console.log`. 

The plugin is based on the fact that you can style your  `console.log` using a `%c` at the beginning of your string and adding a second argument with some CSS styling. 

The following statement
```
console.log('%cHello World', 'color: green; font-weight: bold;');
```
is rendered by the console as follows
![Console.log message in green](/assets/images/2015/01/Screen-Shot-2015-01-10-at-9-17-44-AM.png)

My plugin plugin basically does this: 

```
// Save a reference to the original console.log
window.log = window.console.log.bind(console);

// Re-write console.log
window.console.log = function (message) {
  window.log('%c' + message, __self.styles[__self.current_style]);
};
```
As times goes on, the string with the CSS for the `console.log` message changes around. The last one, is just a `color: white;` so you can't see anything that's being logged. 

Obviously, there's a way to fix this. You can just type `console.log('jorge is awesome');`. 

The other intersting part of the code is how to include this code snippet in every tab (the `console.log` is re-written in every tab). That's done by convert the code into a string and appending a `<script>` tag into the page. 

```
var elt = document.createElement("script");
elt.innerHTML = getFunction.toString() + '; startEvilConsole();';
document.head.appendChild(elt);
```

If you're curious about the code, you can checck it out the code on [GitHub](https://github.com/thejsj/evil-console). 
