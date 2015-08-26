---
layout: post
title: 'jSass: My Very Own JavaScript SASS Compiler'
date: 2014-12-21 19:27:01.000000000 -08:00
---
A couple of days ago, as part of a two day hackathon at Hack Reactor, I build my very own Sass compiler. For those of you unfamiliar with it, [Sass](http://sass-lang.com/) is a CSS pre-processor and probably the best one out there. There's a lot of Sass compilers out there, but mine is the only one written purely in (and not ported to) JavaScript. 

![jSass in GitHub](/assets/images/2014/12/jSass-Github.png)

### Features

Let's be honest here. This is not fully-fledged Sass compiler, but it has the basic features in Sass. 

##### Nesting

Nesting is probably the most useful feature in Sass. It lets you organize your code and prevent writing to many classes. It also makes maitenance easier. 

```
.main {
 background: green;
 .side {
   background: blue;
   color: #777;
 }
}
```
Compiles to:
```
.main {
  background: green; }
  .main .side {
    background: blue;
    color: #777; }

```

##### Comments

Sass allows inline comments. These are not included in your compiled CSS. 

```
// This is some comment on the .main class
.main {
  display: none;
}
```
Compiles to:

```
.main {
  display: none; }
```

##### Variables

Variables for your CSS. How could this not be useful?

```
$color: purple;
.main {
 background: $color;
 .side {
   background: red;
   color: $color;
 }
}
```
compiles to:

```
.main {
  background: purple; }
  .main .side {
    background: red;
    color: purple; }
```

### Online Compiler

As part of this project, I also made an online UI for the compiler with a couple of examples.

![jSass Online Compiler](/assets/images/2014/12/jSass-Online-Compiler.png)

[Check It Out](http://thejsj.com/2014/jsass/)

### Testing

Obviously, this comes with a testing suite. The testing suite tests the result of jSass against [lib-sass](libsass.org), one of the most common Sass compilers out there. Some of the test are disabled, but that's because the output was off by a space or a new line and it wasn't worth it to invest too much time on making it pass.

![Testing of jSass](/assets/images/2014/12/jSass-tests.png)
