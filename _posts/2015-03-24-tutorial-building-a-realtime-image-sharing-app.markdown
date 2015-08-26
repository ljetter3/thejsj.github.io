---
layout: post
title: 'Tutorial: Building a realtime image sharing app'
date: 2015-03-24 11:05:22.000000000 -07:00
---
Recently, I built a [simple realtime image sharing app](http://realtime-photo.thejsj.com/). In this app, images can be uploaded, deleted, and moved around, all in realtime. The app uses [RethinkDB changefeeds](http://rethinkdb.com/docs/changefeeds/javascript/) and [binary objects stored in the database](http://rethinkdb.com/api/javascript/#binary) to push changes to a Node.js server which then publishes changes to all clients through a socket connection. Inspired by this app, I decided to write a short tutorial on how to make a similar app.

In this blog post, I'll walk you through some of the basics of making a realtime drag-and-drop image sharing application. Users can drop images to be saved in the database, and the client will show the last saved image. You can see the code by going to the [GitHub repository](https://github.com/thejsj/realtime-photo-tutorial). I won't necessarily have every line of code in this post (although most of it is here), so you'll have to look at the [repo](https://github.com/thejsj/realtime-photo-tutorial) to see the whole application.

Here's what it looks like:

![](/assets/images/2015/03/screencast-2-1.gif)

Here's how to get it running:

```
// Install and run RethinkDB -> rethinkdb.com/docs/install/
git clone https://github.com/thejsj/realtime-photo-tutorial.git
cd realtime-photo-tutorial
npm install
node server // Go to http://localhost:8000
```

We'll tackle this in 5 steps:

1. Client: Setting up the HTML
1. Client: Sending images to the server
1. Server: Saving images
1. Server: Listening for new images and sending them to the client
1. Client: Listening for new images and displaying images

As you can see, the order mirrors how the process looks like when a user uploads an image, which will make  the process easier to understand.

Some of the things we'll cover are: client-side FileReader, Buffers, base64 encoding, storing binary data in the database, and RethinkDB changefeeds. If you don't know much about some of these, you should definitely keep on reading!

### 1. Client: Setting up the HTML

[*See on GitHub*](https://github.com/thejsj/realtime-photo-tutorial/blob/master/client/index.html)

The first thing we're going to do is setup the HTML file with some divs and links to our JavaScript files. We'll use jQuery for HTTP Requests and some light DOM manipulation and socket.io for socket connections. The two files we'll work on in the client side are `drag-and-drop.js` and `socket-handler.js`.

```html
<html>
  <head>
    <title>Realtime-Photo Tutorial</title>
    <script src="/socket.io/socket.io.js"></script>
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.2/jquery.min.js"></script>
  </head>
  <body>
    <div id='dropzone'>
      <p>Drop Images Here</p>
    </div>
    <div id='images'></div>
    <script src='./drag-and-drop.js' type='text/javascript'></script>
    <script src='./socket-handler.js' type='text/javascript'></script>
  </body>
</html>
```

### 2. Client: Sending images to the server

[*See on GitHub*](https://github.com/thejsj/realtime-photo-tutorial/blob/master/client/drag-and-drop.js)

After setting up the initial HTML file, we'll add a listener on the `dropzone` div to listen for when files have been dropped into the div.
```
var el = document.getElementById('dropzone');

el.addEventListener('drop', function(evt) {
  evt.preventDefault();
  evt.stopPropagation();
  
  // ...
  
 }, false);

el.addEventListener('dragover', function (evt) {
  evt.stopPropagation();
  evt.preventDefault();
  evt.dataTransfer.dropEffect = 'copy'; 
});
```
The event we're really interested in is the `drop` event. This event provides a `event.dataTransfer.files` array (well, technically a [FileList](https://developer.mozilla.org/en-US/docs/Web/API/FileList)) that we can use to access the files that have been dropped in by the user.

Inside the listener, we'll take the first file of `evt.dataTransfer.files` and append it to our `FormData` object through a `file` attribute. Then, we append the `fileName` and the `type` to our `FormData` object and send that object to `http://localhost:8000/image` using an HTTP POST request. 

```
el.addEventListener("drop", function(evt) {

  // prevent default action (open as link for some elements)
  evt.preventDefault();
  evt.stopPropagation();

  // Get the first file only
  var file = evt.dataTransfer.files[0]; // FileList object.

  var data = new FormData();
  data.append('file', file);
  data.append('fileName', file.name);
  data.append('type', file.type);

  // Send an HTTP POST request using the jquery
  $.ajax({
    url: '/image',
    data: data,
    processData: false,
    contentType: false,
    type: 'POST',
    success: function(data){
      console.log('Image uploaded!');
    }
  });
}, false);
```
Now it's time for the server to save the image.

### 3. Server: Saving images

[*See on GitHub*](https://github.com/thejsj/realtime-photo-tutorial/blob/master/server/image-create.js)

In our server, we have a route at `POST /image` that leads to our `imageCreate` function. If you don't know much about express.js routes and want to see how this is setup, check out [my index.js file](https://github.com/thejsj/realtime-photo-tutorial/blob/master/server/index.js) in the repository. Like any other endpoint, this function takes a request and a response as arguments.

```
var _ = require('lodash');
var r = require('./db');
var multiparty = require('multiparty');
var fs = require('fs');

var imageCreate = function (req, res) {
  // ...
};

module.exports = imageCreate;
```
Because this endpoint is handling multipart form data, we need to parse the form. For this we'll use [multiparty](https://github.com/andrewrk/node-multiparty/), a really good `multipart/form-data` handler. Our function now looks like this:

```
var imageCreate = function (req, res) {
  var form = new multiparty.Form();
  form.parse(req, function (err, fields, files) {
  // ...
  });
};
```
The `parse` function provides us with two important variables: `fields` and `files`. We'll use these variables to get our form data and get our image. The `files` array provides us with a path we can use to read the file in our system.

```
var imageCreate = function (req, res) {

  var form = new multiparty.Form();
  form.parse(req, function (err, fields, files) {
    var imageFilePath = files.file[0].path; 
    var image = {
      fileName: fields.fileName[0],
      type: fields.type[0],
    };
    fs.readFile(imageFilePath, function (err, buffer) {
    // ...
    });
  });
};
```
Once we have an `imageFilePath`, we use `fs` (file system) to read the file. The [`readFile`](https://nodejs.org/api/fs.html#fs_fs_readfile_filename_options_callback) function gives us back a [`Buffer`](https://nodejs.org/api/buffer.html). After reading the file from the file system, we'll convert that buffer into an [`r.binary`](http://rethinkdb.com/api/javascript/#binary) object. This `r.binary` method converts our buffer into something that can be stored in the database. After that, we just [`insert`](http://www.rethinkdb.com/api/python/insert/) the object into the `images` table. Finally, we pass on the `id` of our new document to the client as the HTTP response.

```
fs.readFile(imageFilePath, function (err, buffer) {
  image.file = r.binary(buffer);
  r
    .table('images')
    .insert(image)
    .run(r.conn)
    .then(function (query_result) {
      res.json( {
        id: req.params.id
      });
    });
});
```


At this point, we've setup everything we need to add images to our database, but how do we make sure that all clients see the newly uploaded images? This is where [changefeeds](http://rethinkdb.com/docs/changefeeds/javascript/) come in!

### 4. Server: Listening for new images and sending them to the client

[*See on GitHub*](https://github.com/thejsj/realtime-photo-tutorial/blob/master/server/socket-handler.js)

Usually, in a realtime application we need to update clients when changes have been made to the database. But keeping track of changes in the database can be pretty difficult. Solutions range form in-memory stores, to polling, to message queues, to querying the database every time an action is taken. With RethinkDB, we can just setup a listener for changes in our `images` table and be done with it.

Here's how that works:

In our server, we've created a [socket handler](https://github.com/thejsj/realtime-photo-tutorial/blob/master/server/socket-handler.js) to take care of our socket connections. It's connected to socket.io in our [server/index.js](https://github.com/thejsj/realtime-photo-tutorial/blob/master/server/index.js#L30). Whenever there's a new socket connection, this function will be called and handle the different emits to and from the client.

```
var r = require('./db');

var socketHandler = function (io, socket) {
  // ...
};
module.exports = socketHandler;
```
The first thing we're going to do inside the socket handler is create a new connection to our RethinkDB database. Every changefeed needs its own connection to the database in order to work properly.

```
var socketHandler = function (io, socket) {
  r.getNewConnection()
    .then(function (conn) {
      // ...
    });
};
```
After creating the new connection, we're going to query all documents in the `images` table and then listen to changes on that table. Our `.run` method will return a cursor to which we can then pass a callback. This callback will get fired every time there's a change in that query.

```
var socketHandler = function (io, socket) {
  r.getNewConnection()
    .then(function (conn) {
      r.table('images')
        .changes()
        .run(conn)
        .then(function (cursor) {
          cursor.each(function (err, result) {
            // Will get executed every time there's a
            // change in the `images` table
          });
        });
     });
};
```
Now that we are listening to changes in the `images` table, we need to specify what we're going to do once we get that change. In this case, we're going to confirm that the image hasn't been deleted and then emit a new event (with our image) through our socket connection.

```
r
  .table('images')
  .changes()
  .run(conn)
  .then(function (cursor) {
    cursor.each(function (err, image) {
      // Push images through the socket connection
      if (image.new_val !== null) {
        io.emit('Image:update', image.new_val);
      }
    });
  });
});
```
Our server is now sending all newly created images to our client through our socket connection. The last thing we need to do now is display the images that we get from the client.

### 5. Client: Listening for new images and displaying images

[*See on GitHub*](https://github.com/thejsj/realtime-photo-tutorial/blob/master/client/socket-handler.js)

On our client side, we'll now create a new file called `socket-handler.js` which we already included in our HTML in step 1. In this file, we'll connect to our server through Socket.io and listen for new image updates. Our file starts off with this: 

```
var socket = io.connect('http://localhost:8000');

socket.on('Image:update', function (image) {
 // ...
});
```
After setting the listener for `Image:update` ([See where this is triggered](https://github.com/thejsj/realtime-photo-tutorial/blob/master/server/socket-handler.js#L18)), we now have to read the image, convert it into a base64 string, add it to an `<img>` and then append it to the DOM. For converting the file into a base64 string, we'll use the [`FileReader`](https://developer.mozilla.org/en-US/docs/Web/API/FileReader) class and it's `readAsDataURL` method.

When we first get the image file, the file is an [`ArrayBuffer`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/ArrayBuffer). ArrayBuffers are used to represent binary data in JavaScript. We then convert that `ArrayBuffer` into a `Blob`, which the browser can then read using the `FileReader`. The `readAsDataURL` will return a base64 string. We can use this string to create an `<img>`.
```
socket.on('Image:update', function (image) {
  var reader = new FileReader();
  reader.onload = function(e) {
    $('#images')
      .html('<img src="' + e.target.result + '" />');
  }.bind(this);
  reader.readAsDataURL(new Blob([image.file]));
});
```
The reason we need to convert it to base64 is that the `<img>` tag can't read binary data directly. We need to convert it to something HTML can read. Base64 converts our binary data into a string, which we can then pass on to the `src` attribute of our image. The `readAsDataUrl` method reads our file asynchronously and provides us with a base64 string.

### Final thoughts

Realtime binary updates are really powerful. There's so much stuff you can make with them! Once you get over the initial complexity of Buffers, Blobs, FileReader and all this dealing with uploading images is not hard. Go ahead and try it out!

If you still haven't tried it out, you should definitely checkout [RethinkDB](http://rethinkdb.com/docs/install/). It's not only a pleasure to use, but it will make realtime apps that much easier!

