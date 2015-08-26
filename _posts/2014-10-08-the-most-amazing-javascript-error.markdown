---
layout: post
title: The Most Amazing Javascript Error
date: 2014-10-08 16:16:44.000000000 -07:00
---
Today, after upgrading chrome to Chrome 38, I got the most amazing JavaScript error I've ever gotten in my life! 

![The Most Amazing JavaScript Error](/assets/images/2014/Oct/Screen-Shot-2014-10-08-at-4-24-07-PM.png)

Basically, my [polyfill for the picture element](https://github.com/scottjehl/picturefill) wasn't loaded! That means that, with the new version of Chrome, the picture element is supported out of the box and there's not need for the polyfill (hence, why a call to the polyfill broke the site). 

I was intrigued. I was marveled. I was so happy! Looking forward to the next Chrome update that breaks my site!
