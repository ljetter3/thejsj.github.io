---
layout: post
title: Writing my own JSON.parse
date: 2014-10-05 19:20:16.000000000 -07:00
---
![](/assets/images/2014/Oct/douglas-big-1.jpg)

I wrote my own `JSON.parse`! Since I found this process to be quite interesting, I decided to write a bit about how I went about it. Of course, doug helped me out a bit!

### The Basics

Basically, the `parseJSON` function is a wrapper for an inner function called `parseJSONString`.

```javascript
var parseJSON = function (json) {
  return parseJSONString(json);
};
```

### Identifying Types

`parseJSONString` recursively goes through the string and parses the string into an array, an object, a number, a string, a boolean, `null`, or `undefined`. If the function is not able to recognize any of these, it throws an error. This is important for finding strings that are not proper JSON. 

```javascript
var parseJSONString = function (str, parent) {
    str = str.trim();
    if (isArray(str)) {
      return separeateStringByCommas(removeFirstAndLastChar(str))
        .map(parseJSONString);
    } else if (isObj(str)) {
      /**
       * I wanted to do something elegant that could
       * parse object key/value pairs nicely with regular expressions, but
       * Douglas Crockford seems to think that's a bad idea!
       * `splitByChar` is hesitantly inspired by this code:
       * https://github.com/douglascrockford/JSON-js/blob/master/json_parse.js
       */
      var obj = {};
      var _obj = separeateStringByCommas(removeFirstAndLastChar(str));
      // _obj is an array of strings with 'key: value'
      _obj.forEach(function (val, i) {
        // split into key, value
        var key_val_pair = separeateStringByColons(val);
        if (key_val_pair.length === 2) {
          obj[parseJSONString(key_val_pair[0])] = 
            parseJSONString(key_val_pair[1]);
        }
      });
      return obj;
    } else if (isString(str)) {
      // unescape string
      return removeFirstAndLastChar(str)
        .replace(/([\\]{1})([\\\"]{1})/g, '$2');
    } else
    if (isNumber(str)) {
      return +str;
    }
    if (str === 'null') return null;
    if (str === 'false') return false;
    if (str === 'true') return true;
    if (str === 'undefined') return undefined;
    throw new SyntaxError('Unexpected end of input');
  };
```

In order to recognize types, we create a couple of functions that look at the first and last characters of a string and also check if it's a number. We add a bit of fanciness to this, by creating a higher-oder function `firstAndLastChars` that makes creating these functions easier. These are all pretty simple.

```javascript
// Higher-order function to be used for detecting type
  var firstAndLastChars = function (first, last) {
    return function (str) {
      return str[0] === first && str[str.length - 1] === last;
    };
  };
  var isArray = firstAndLastChars('[', ']');
  var isObj = firstAndLastChars('{', '}');
  var hasDoubleQuotes = firstAndLastChars('"', '"');
  var hasSingleQuotes = firstAndLastChars("'", "'");
  var isString = function (str) {
    str = str.trim();
    return (hasSingleQuotes(str) || hasDoubleQuotes(str)) 
        && str[str.length - 2] !== '\\';
  };
  var isNumber = function (str) {
    return (+(str)) + '' === str;
  };
  var removeFirstAndLastChar = function (str) {
    str = str.trim();
    return str.substring(1).slice(0, str.length - 2) || '';
  };
```

### Parsing Objects and Arrays

The most challenging parse about all this was parsing JSON strings of objects and arrays into objects and arrays. 

For a couple of hours, I got stuck trying to parse objects, arrays and strings with commas using only regular expressions. I figured this would be the most elegant way to do it, since it could be done in only one line of code! After an hour or two, I started to think that my knowledge of regular expressions was too limited to handle this. At this point, I turned to google.

I found one of Douglas Crockford's JSON implementations on his Github page. One of the comments in his code read: 

```javascript
// This is a function that can parse a JSON text, producing a JavaScript
// data structure. It is a simple, recursive descent parser. It does not use
// eval or regular expressions, so it can be used as a model for implementing
// a JSON parser in other languages.
```

https://github.com/douglascrockford/JSON-js/blob/master/json_parse.js#L56-L59

The interesting part is that, if you look at his code, it's actually quite procedural. It goes characther by charachter trying to decifer what to parse it into. 

![Self half-five!](/assets/images/2014/Oct/download.gif)

At that point, I felt way more comfortable not using regular expressions! Again, I turned to higher-order functions and decided to write a higher-order function that would split strings by a designated character whenever they were not inside a string ("" and ''), an array ([]), or an object ({}). Then I went ahead and created one for commas and colon (to separate key value pairs in objects). 

```javascript
// Higher-order function to be used for splitting string
  var splitByChar = function (base_char) {
    return function (str) {
      var result = [];
      var double_string_open = false;
      var single_string_open = false;
      var array_open = false;
      var object_open = false;
      var array_bracket_count = 0;
      var object_bracket_count = 0;
      var curr_str = '';
      var prev_ch = '';
      for (var i = 0; i < str.length; i += 1) {
        var ch = str[i];
        if (ch === '"') {
          double_string_open = !double_string_open;
        }
        if (ch === "'") {
          single_string_open = !single_string_open;
        }
        if (ch === '[') {
          array_bracket_count += 1;
          array_open = true;
        }
        if (ch === ']') {
          array_bracket_count -= 1;
          if (array_bracket_count === 0) {
            array_open = false;
          }
        }
        if (ch === '{') {
          object_bracket_count += 1;
          object_open = true;
        }
        if (ch === '}') {
          object_bracket_count -= 1;
          if (object_bracket_count === 0) {
            object_open = false;
          }
        }
        if (ch === base_char 
        && !double_string_open 
        && !single_string_open 
        && !array_open && !object_open
        ) {
          if (curr_str !== '') result.push(curr_str.trim());
          curr_str = '';
          prev_ch = '';
        } else {
          curr_str += ch;
          prev_ch = ch;
        }
      }
      if (curr_str !== '') result.push(curr_str.trim());
      return result;
    };
  };
  var separeateStringByCommas = splitByChar(',');
  var separeateStringByColons = splitByChar(':');
```

Looking back on this, it seems quite obvious that regular expressions were not the way to go. Nested objects and arrays seem a bit too complicated for that. Honestly, I think that has a bit to do with my desire to make my code look smarter. Not more understandable! I just want my code to make ME feel smart. Obviously, this is a horrible approach to writing good code! 

### Result

Ultimately I grouped this into type detection functions, functions for splitting strings and then my `parseJSONString` method. I made these all inner functions, in order to keep the global namespace cleaner.

Here's the whole thing:

<script src="https://gist.github.com/thejsj/aad9c0392a59a7d87d9c.js"></script>
