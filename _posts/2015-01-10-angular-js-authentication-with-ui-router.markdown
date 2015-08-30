---
layout: post
title: Angular.js Authentication with UI-Router
date: 2015-01-10 09:26:59.000000000 -08:00
---
When authenticating users in single page applications, there are two basic ways of going about it: token-based authentication and server-side authentication. For our angular.js app, CodeFriends, we decided to use sever-side authentication. 

When using [UI Router](http://angular-ui.github.io/ui-router/site/#/api/ui.router), the best way we found to handle authentication is to use the `resolve.authenticated` method in the state configurations. This function, when passed to our `$state`, will determine if the user can continue to that view. It is only after our function has resolved that the controller is loaded. 

Let's take a look at how this looks in our code:

First, let's set up the views with their corresponding `resolve` methods:

```javascript
.config(function ($stateProvider, $urlRouterProvider) {
      
      // ...
      
      $stateProvider
        .state('landing', {
          templateUrl: '/app/landing/landing.html',
          controller: 'landingController',
          url: '/'
        })
        .state('login', {
          templateUrl: '/app/login/login.html',
          controller: 'loginController',
          url: '/login',
        })
        .state('home', {
          url: '/home',
          views: {
            
            // ... 
            
          },
          resolve: {
            authenticated: authenticated
          }
        })
        .state('project', {
          url: '/project/:projectName/:projectId',
          views: {
            
            // ...

          },
          resolve: {
            authenticated: authenticated
          }
        })
        .state('document', {
          parent: 'project',
          url: 'document/:documentPath',
          templateUrl: '/app/project/document/document.html',
          controller: 'documentController',
          resolve: {
            authenticated: authenticated
          }
        });
    })
```

Notice how we have specified passed the `authenticated` variable into `resolve.authenticated`. This will be a function which we'll write as follows: 

```javascript
.config(function ($stateProvider, $urlRouterProvider) {
      $urlRouterProvider.otherwise('/');
      var authenticated = ['$q', 'Auth', function ($q, Auth) {
        var deferred = $q.defer();
        Auth.isLoggedIn(false)
          .then(function (isLoggedIn) {
            if (isLoggedIn) {
              deferred.resolve();
            } else {
              deferred.reject('Not logged in');
            }
          });
        return deferred.promise;
      }];
      $stateProvider
      
        // ...
    })
```

Our `authenticated` function is a promise. The server (through our `Auth` factory) responds with a boolean which tells us if the user is logged in or not. If the user is logged in, the promise is resolved and the controller is loaded. If ther user is not logged in, the promise is rejected. In order to handle this, we write a function that handles in errors in our routes. 

```javascript
.config(function ($stateProvider, $urlRouterProvider) {
   
   // ...
   
})
.run(function ($rootScope, $state, $log) {
  $rootScope.$on('$stateChangeError', function () {
    // Redirect user to our login page
    $state.go('login');
  });
});
```

And that's it! Server-side authentication with Angular.js. If you want to see the whole code, check out the code on [GitHub](https://github.com/code-friends/CodeFriends/blob/master/client/app/app.js#L23-L101).

To all you Hack Reactor nerds out there, you should really see this [Quora post with old photos of Tony, Marcus, and Shawn](http://qr.ae/6S09G).
