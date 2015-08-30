---
layout: post
title: 'JavaScript Promises In Action: Saving An Image'
date: 2014-12-21 20:01:36.000000000 -08:00
---
Recently, I [wrote an article](/what-are-javascript-promises-and-how-can-i-use-them/) laying out what are JavaScript promises and how they work. Shortly after that, I wrote a controller saving images for [kbitzr]() that really exemplified how awesome promises are. 

In this post, I'll go through part of it and try to explain how promises make this code more clear, maintainable and awesome. [This controller](https://github.com/silver-octopus-labs/mlp/blob/master/server/routers/api/photoRouter.js) handles POST requests for our photoRouter. Basically, it adds new photos to our database, saves them, and crops them.

### Requirements

The first thin we'll need to do is `require` some modules. The most important one here is [bluebird](), which we require as `Promise`. The reason it's important is that it let us `require` other modules and 'promisify' them. This lets us interact with them as if they were promise compliant. After that, we layout our POST request handler.

```javascript
var express = require('express');
var Promise = require('bluebird');
var Q = require('q');
var imageMagick = Promise.promisifyAll(require('imagemagick'));
var fs = Promise.promisifyAll(require("fs"));
// ... even more stuff.

photoRouter.post('/', function (req, res) {

});
```

### Parsing Form Data

After that, we write some code to get all the correct data from our form. I'm ommitting this part because it doesn't have much to do with promises but you can check that part out [here](https://github.com/silver-octopus-labs/mlp/blob/master/server/routers/api/photoRouter.js#L26-L47).

### Writing Our Function

After we promisified all our functions and have all the data/paths we need to process the image, we can finally get to the good stuff. This function will 1. Save the image using ur promisified `fs`, 2. Crop our images using our promisified `imageMagick`, 3. Save the new entry to the database, and 4. Return the appropriate response.

In this first part, we start by creating a base promise using `Q()`. `Q()` ensures all our subsequenet `.then`s and `.catch`s run as promises. At the end of the promise chain, we make sure to return a 400 error if anything goes wrong. If an error is thrown by any of the promises, it will be caught by this last `.catch`.

```javascript
Q().then(function () {

// ... All my code ...

}).catch(function (err) {
  console.log('ERROR: ', err);
  res.status(400).end();
});

```
After this we make sure the data we have is correctly populated. We parse the data a bit to be able to move the temporary image or save base64 data to an image. Keep in mind that many of these variables are [already declared before the function was called](https://github.com/silver-octopus-labs/mlp/blob/master/server/routers/api/photoRouter.js#L26-L47). Once we parse the data correctly, we write or move the file to the correct path and return this as the result of this function. This is an asynchronous operations which returns a promise. If we don't have the data we need, we throw an error which will return a 400 HTTP response.

```javascript
Q().then(function () {
  if (filePath !== null && filePath !== undefined) {
    filePath = path.resolve(filePath);
    fileExtension = _.last(filePath.split('.'));
    newImageFileName = name + '.' + fileExtension;
    newPath = path.join(__dirname, '/../../media/original/', newImageFileName);
    new200Path = path.join(__dirname, '/../../media/square-200px/', newImageFileName);
    new500Path = path.join(__dirname, '/../../media/square-500px/', newImageFileName);
    return fs.chmodAsync(filePath, '0777')
      .then(function () {
        return fs.renameAsync(filePath, newPath);
      });
  }
  if (base64Data) {
    fileExtension = 'png';
    newImageFileName = name + '.' + fileExtension;
    newPath = path.join(__dirname, '/../../media/original/', newImageFileName);
    new200Path = path.join(__dirname, '/../../media/square-200px/', newImageFileName);
    new500Path = path.join(__dirname, '/../../media/square-500px/', newImageFileName);
    return fs.writeFileAsync(newPath, base64Data, 'base64');
  }
  throw new Error('Nothing To Do');
})
```
Now that our image file was saved, we can crop it. For this, we also promisify `imageMagick` in order for it to always return a promise. If the image is cropped succssefully, the promise chain will continue executing. If not, it will error out. 

```javascript
.then(function () {
  return imageMagick.cropAsync({
    srcPath: newPath,
    dstPath: new200Path,
    width: 200,
    height: 200
  });
}).then(function () {
  return imageMagick.cropAsync({
    srcPath: newPath,
    dstPath: new500Path,
    width: 500,
    height: 500
  });
}).then(function () {
```
When image is saved and cropped, the image is finally saved to the database with its filename. Keep in mind that the `userId`, `promptId`, and `newImageFileName` were declared at the top of our function. The `.save()` method also returns a promise (but you knew that already, right!).

```javascript
}).then(function () {
  return new models.Photo({
      user_id: userId,
      prompt_id: promptId,
      filename: newImageFileName // Relative to /media/
    })
    .save();
}).then(function (photo) {
```
Finally, if everything goes according to plan, we return a 200 HTTP response with the photo data in JSON format. `photo` is the model created after saving it to the database.

```javascript
}).then(function (photo) {
  res.json(photo.toJSON());
}).catch(function (err) {
```
Here it is all together ([See it on Github](https://github.com/silver-octopus-labs/mlp/blob/master/server/routers/api/photoRouter.js)):

```javascript
Q().then(function () {
  if (filePath !== null && filePath !== undefined) {
    filePath = path.resolve(filePath);
    fileExtension = _.last(filePath.split('.'));
    newImageFileName = name + '.' + fileExtension;
    newPath = path.join(__dirname, '/../../media/original/', newImageFileName);
    new200Path = path.join(__dirname, '/../../media/square-200px/', newImageFileName);
    new500Path = path.join(__dirname, '/../../media/square-500px/', newImageFileName);
    return fs.chmodAsync(filePath, '0777')
      .then(function () {
        return fs.renameAsync(filePath, newPath);
      });
  }
  if (base64Data) {
    fileExtension = 'png';
    newImageFileName = name + '.' + fileExtension;
    newPath = path.join(__dirname, '/../../media/original/', newImageFileName);
    new200Path = path.join(__dirname, '/../../media/square-200px/', newImageFileName);
    new500Path = path.join(__dirname, '/../../media/square-500px/', newImageFileName);
    return fs.writeFileAsync(newPath, base64Data, 'base64');
  }
  throw new Error('Nothing To Do');
})
.then(function () {
  return imageMagick.cropAsync({
    srcPath: newPath,
    dstPath: new200Path,
    width: 200,
    height: 200
  });
}).then(function () {
  return imageMagick.cropAsync({
    srcPath: newPath,
    dstPath: new500Path,
    width: 500,
    height: 500
  });
}).then(function () {
  return new models.Photo({
      user_id: userId,
      prompt_id: promptId,
      filename: newImageFileName // Relative to /media/
    })
    .save();
}).then(function (photo) {
  res.json(photo.toJSON());
}).catch(function (err) {
  console.log('ERROR: ', err);
  res.status(400).end();
});
```
### Conclusion

Hope this example helps you understand promises and why the are so infinetly useful! Saving an image might not be the easiest example out there, but it's a very common operation in web applications. If you didn't get this post, I'd recommend checking out [my other post explaining promises](/what-are-javascript-promises-and-how-can-i-use-them/). It explains promises with a bit more detail and with easier examples.
