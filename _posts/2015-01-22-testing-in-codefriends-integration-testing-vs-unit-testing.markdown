---
layout: post
title: 'Testing in CodeFriends: Integration Testing vs Unit Testing'
date: 2015-01-22 14:45:16.000000000 -08:00
---

For my recent project [CodeFriends](http://codefriends.io), me and my teammates wrote an integration testing suite for our API. In the last couple of days, I've thought a lot about the pros and cons of this approach and thought I'd share them here. This is not a definitive guide on the subject, but rather a real world case study for people who might not be using any testing right now or want have only done unit testing.
 
## What We Did

How about I just show you!

![CodeFriends Integration Testing Suite /#1](/assets/images/2015/01/CodeFriends-Testing-Suite--1.png)
![CodeFriends Integration Testing Suite /#2](/assets/images/2015/01/CodeFriends-Testing-Suite--2.png)

These screenshots show our 39 tests. Every single one of these tests makes at least one http request over the network and uses our real database infrasctrucutre to store data. We use a testing database which is created at the start and wiped out at the end.

For writing these tests, we used [supertest-as-promised](https://www.npmjs.com/package/supertest-as-promised). It's a thin wrapper over [supertest](https://github.com/tj/supertest), which basically makes our http requests, keeps our session open and makes some basic assertions about it. In this next example, a project is created using a POST request. Then we execute a GET request to get the object and `expect` checks to see if all the necessary properties are there. 

```
it('should create a new project on POST /project', function (done) {
    agent
      .post('/api/project')
      .send({
        projectName: 'tennis'
      })
      .expect(201)
      .end(function (err, res) {
        var _project = res.body;
        agent
          .get('/api/project/' + _project.projectName)
          .expect(200)
          .end(function (err, res) {
            var project = res.body;
            project.should.have.property('id');
            project.should.have.property('projectName');
            project.projectName.should.equal(_project.projectName);
            project.should.have.property('createdAt');
            project.should.have.property('updatedAt');
            project.should.have.property('user');
            project.user.should.be.instanceof(Array);
            done();
          });
      });
  });
```
It might seem a little weird that we're doing this, but at the beginning of this project our API routes were pretty thin. This `POST /api/project` route, for example, [is only about 20 lines of code](https://github.com/code-friends/CodeFriends/blob/master/server/project/projectController.js#L29-L52)! At the time, it seemed like a bit of overkill to write unit tests for it.
 
## Was this a good approach?

Let's get to the interesting part! The answer, of course, is yes and no. I'll try to layout some of the things we found while taking on this approach.

#### Of Course It Was! Integration Testing Rocks!

The nice thing about this approach is that we were able to know (in about 45 seconds) if our API was working or not. If the tests were failing, something is broken. If the tests were passing, everything was fine. If something was broken and all the tests were passing, that meant we had write more tests. Pretty simple. 

Because of this, merging pull requests was pretty straightforward. Merging pull request often relied on how good the **tests** for a particular feature were, not necesarilly how the code was written. We relied a lot on Travis CI to run our full testing suite and decide to deploy/merge based on that.

As you can imagine, we all love the color green now!
![Travis CI](/assets/images/2015/01/Screen-Shot-2015-01-27-at-12-09-29-PM.png)

The best part about all this was that, when something wasn't working, we could pretty confidently blame the front-end team! Isn't that enough of a reason to start writing tests!
 
#### Oh no! Keep these integrations tests out of here!
 
For the most part, I was pretty happy with this. We were able to check if we broke anything while writing new features and we were able to confidently deploy our app to staging. 

Then two things happend.

###### Git Cloning

One of the coolest features we were able to implement was cloning a git repo into CodeFriends. Behind the scenes, this meant that our server was cloning the git repository into our server's file system and then, one by one (order is important), reading the contests of those files and importing it into our virtual file system. 

We implemnted this and it worked! Our tests were passing and everything was good! But after a while, we noticed that it wasn't working for bigger project so we wrote a tests that imported our own repo into the file structure. We are so meta. There was only one problem. The test took between 15 seconds and 25 seconds.

![CodeFriends Testing Suite - 18 seconds](/assets/images/2015/01/CodeFriends-Testing-Suite---18-seconds.png)

This was way too long. Ultimately, we left it there and ran it every single time we run the testing suite, ocasionally turning it off. 

###### Bugs

The other problem we ran into were bugs. Our tesing suite was very good at telling us when our API was broken, but wasn't very good at telling me **why** it was broken. For that, we had to undo any changes that broke our test, or we had to spend a very long time looking at why exactly our app was broken. That part was not very efficient.

A lot of times, this had something to do with the fact that tests depended on previous data that was supposed to be on the database at a particular point in time. Basically, our testing suite was very stateful. Not a good idea. 
 
## Conclusion 

Ultimately, our testing suite was incredibly useful. Much more useful than most people expect a testing suite to be. It answered the most important question you need to know at any point during development: "Is my app working?". This level of confidence is a bit harder with unit testing, because you're not testing some of the components that lead to a lot of bugs (databases, interactions between different components, depndencies, etc.). Obviously, our second question "Why is my app not working?" is a little harder to answer with integration test and easier to answer with unit testing. 

So here's what I recommend. If you want to do it the right way, start writing unit tests for everything and slowly start writing integration tests. If you're writing a CRUD app and don't want to go deep into testing, write integration tests first and add unit testing for parts of your application that are more complex. If you're doing it right, you'll have the confidence to know if you application will work in production.
