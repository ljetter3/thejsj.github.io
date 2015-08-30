---
layout: post
title: Is it possible to implement an `if` method? A look at the ReQL `branch` method
date: 2015-04-13 12:28:35.000000000 -07:00
---
One of the things that makes [RethinkDB](http://rethinkdb.com/) different from other databases is that its query language is embedded into the programming language. Unlike SQL, you use ReQL by installing a client driver for your programming langauge and building queries with this driver. The driver builds a query and then sends that query to the server to be executed and returned. An example of a ReQL query looks like this:

```javascript
r.table('people')
 .filter({ name: 'jorge' })
 .run(conn)
 .then(function (rows) {
   console.log(rows);
 });
```

This query gets all the rows in the `people` table with 'jorge' as the values in the `name` field.

```javascript
{
  "id":  "db68bcdf-05c8-41fa-a80d-f301a872af24" ,
  "last_name":  "washington" ,
  "name":  "jorge"
}, {
  "id":  "e40409e0-0b46-4ce9-9e4c-2e2211d8df8b" ,
  "last_name":  "silva" ,
  "name":  "jorge"
}
```

One of the things I started doing pretty quickly when I started using ReQL is adding `if` statements to my code. Looking at the code above, what happens if we just filtered the rows through an `if` statement.

```javascript
r.table('people')
  .filter(function (row) { 
    if (row('name').eq('jorge')) return true; 
    return false;
  });
```

Instead of doing what you'd expect it to, this function returns `true` for all rows, basically ignoring our `if` statement. 

```javascript
{
  "id":  "db68bcdf-05c8-41fa-a80d-f301a872af24" ,
  "last_name":  "washington" ,
  "name":  "jorge"
}, {
  "id":  "dd99e938-aaac-467c-a2fd-efbba0c4af1b" ,
  "last_name":  "adams" ,
  "name":  "john"
}, {
  "id":  "e40409e0-0b46-4ce9-9e4c-2e2211d8df8b" ,
  "last_name":  "silva" ,
  "name":  "jorge"
}
```

After making this mistake a couple of times, I found the [`branch`](http://rethinkdb.com/api/javascript/branch/) method. This method works basically as an `if` statement. The first argument is the condition to be tested. The second argument is what the function will return if the condition is true. The third argument is what the function will return if the condition is false. With `branch`, the same query we wrote before would look like this:

```javascript
r.table('people')
  .filter(function (row) { 
     return r.branch(
      row('name').eq('jorge'), // if 'name' === 'jorge'
        true, 
        false
     ); 
  });
  // Same as...
  // .filter({ name: 'jorge' })
```  

And it would return this:

```javascript
{
  "id":  "db68bcdf-05c8-41fa-a80d-f301a872af24" ,
  "last_name":  "washington" ,
  "name":  "jorge"
}, {
  "id":  "e40409e0-0b46-4ce9-9e4c-2e2211d8df8b" ,
  "last_name":  "silva" ,
  "name":  "jorge"
}
```

Exactly what we wanted!

If you think about this for a minute, it makes perfect sense. Because ReQL is a query language that lives inside your programming language, it needs its own way of having `if` statements, so that it can then transform these into a query to send to the server. The `branch` method does exactly that. Its a function to have an `if` statement inside RethinkDB's query language. This method is not called `r.if` because in many languages `if` is a reserved keyword and you won't able to create a method named `if` in all languages. 

### Implementing an `if` method

After realizing that you can't create an `if` methods in all languages, I was curious about what languagues would permit creating an `if` method and which ones wouldn't. I tried doing this in three languages: JavaScript, Ruby, and Python. Here's how it went:

#### JavaScript

In JavaScript, this was fairly simple. JavaScript objects can use reserved keywords as property names. 

```javascript
var sample = {
  if: function (condition, ifTrue, ifFalse) {
    if (condition) return ifTrue;
    return ifFalse;
  }
};
sample.if(true, true, false); // true
sample.if(false, true, false); // false
```

That being said, you can't create a function called `if`. 

```javascript
var if = function ()  {
  console.log('This is an `if` function');
};
if();
```

That would throw a syntax error: 

```
SyntaxError: Unexpected token if
```

#### Ruby

Ruby also allows a class to have an `if` method: 
  
```ruby
class SampleClass
  def if(condition, true_statement, false_statement)
    if condition
      return true_statement
    false_statement
  end
end

a = SampleClass.new()
puts a.if(true, true, false) // true
puts a.if(false, true, false) // false
```

#### Python

Python is a less permissive about its reserved keywords. If we try to create a class with an `if` method, Python will throw an error. 

```python
class SampleClass():

    def if(self, condition, true_statement, false_statement):
        if (condition) return true_statement
        return false_statement

sample = SampleClass()
print sample.if(True, True, False)
```

Throws:

```
  File "if.py", line 6
    def if(self, condition, true_statement, false_statement):
         ^
SyntaxError: invalid syntax
```

There is a way in which to do this, but it's not very elegant. You can have a function as an  `if` attribute on a dictionary and then you'd be able to call it using brackets.

```python
class SampleClass():

    def __init__(self):
        self.data = {}
        self['if'] = self.create_if_function()

    def create_if_function(self):
        def function(self, condition, if_true, if_false):
            if (condition) return if_true
            return if_false
        return function

    def __setitem__(self, key, item):
        self.data[key] = item

    def __getitem__(self, key):
        return self.data[key]

sample = SampleClass()
sample['if'](True, True, False) // True
sample['if'](False, True, False) // False
```

While this works, it's not very clear what exactly this function does because of the brackets.

### Final Thoughts

It's interesting to see what goes into building a query language on top of programming language in the way that ReQL does. This process always carries trade-offs. The difficulty lies in handling these trade-offs elegantly, which is something ReQL does extremely well. The `branch` method is an excellent example of this. It's a method that is consistent across all drivers and programming languages where ReQL is implemented. At the same time, its name provides a very clear idea of what it does and how it should work.
