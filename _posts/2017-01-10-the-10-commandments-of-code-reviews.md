---
layout: post
title: The 10 Commandments of Code Reviews
date: 2017-01-10 00:00:00 -08:00
---

_This post is a re-post of my blog post in the [Runnable Blog](http://runnable.com/blog), as part of my work for [Runnable](http://www.runnable.com). [Check out the original post](https://runnable.com/blog/the-10-commandments-of-code-reviews)._

Code reviews are one of the most important parts of an engineering team’s workflow. The benefits of code reviews include: creating visibility for new changes, preventing bugs, improving code quality, and creating cohesive patterns. Despite the benefits, code reviews can sometimes create tension in the team: some developers are stricter than others, some take a long time to review, etc.. Often, these tensions come from a lack of agreement of how code reviews should be conducted and what the roles of a reviewer and a submitter should be.

I wrote the 10 commandments for code reviews, to create a common understanding for reviewers and submitters about how code reviews should be conducted. By following them, teams share a common understanding of their responsibilities, reduce the tension between teammates, and deploy their code faster. Since reviewers and submitters have very different responsibilities, I split the 10 commandments in 2—5 commandments for each role. Each set of commandments were written with the other set in mind, which means that both sides need to obey the commandments to reap the benefits.

It’s important to note that, while making these, I made two assumptions. The first one is that the person submitting the code is responsible and wants to do their best work. The second assumption is that code reviews should not be an impediment to speed.

### _For Code Submitters_

### #1 Thou shalt always make code reviews short.

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">10 lines of code = 10 issues.<br><br>500 lines of code = &quot;looks fine.&quot;<br><br>Code reviews.</p>&mdash; I Am Devloper (@iamdevloper) <a href="https://twitter.com/iamdevloper/status/397664295875805184">November 5, 2013</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

One of the easiest ways to make a review difficult is to make it very, very long. Making a review long puts a burden on the reviewer to spend a lot of time reviewing code, who then might be tempted to approve the change despite not fully understanding the code. For this reason, all reviews need to be short. This makes it easier for the reviewer see potential problems the code might introduce.

In our experience at Runnable, we found that 400 lines of code for Javascript is a good limit for most reviews. This includes tests, which tend to be a bit verbose, so this might be about 200 lines of code if the code doesn’t include tests. This keeps the review of all the code to somewhere between 15 minutes to under one hour for most cases (YMMV). Your numbers would probably be different depending on the language you’re using: Ruby and Python might have fewer lines of code, while Java and Go might have more.

### #2 Thou shalt always try to incorporate feedback.

Developers are notoriously lazy. Sometimes that laziness can even be a good thing, leading to more efficient automation. When receiving a code review, that laziness is bad since it makes the submitter not incorporate perfectly good feedback. It’s preferable to err on the side of incorporating feedback since the reviewer is looking at the code with fresh eyes.

There will be times when the feedback suggested will actually deteriorate code quality or where an enormous amount of work would be required for minor improvements. When that happens, take the time discuss with your reviewer why you think the suggestions shouldn’t be added.

### #3 Thou shalt not bullshit your reviewer.

The submitter has more knowledge about the code they’ve just written. Because of this, it’s easy for the submitter to bullshit their way out of not doing something. For the code review process to work, the submitter must be honest and transparent about the knowledge they have. You’d be surprised how hard that can be sometimes! It’s easy to try to bullshit your way out of not making the important changes you need in your code.

As a submitter, when you find yourself bullshiting around something, focus on why the process is the way it is, and why there’s tension between you and the reviewer.

### #4 Thou shalt not blindly implement changes.

When the review process has dragged out a bit longer than expected or the submitter wants to merge code quickly, they will ask the reviewer, “what do you want me to change?”. This is different from, “how do you think we should solve this?”, and means that the submitter stopped caring about the implementation and will blindly implement what they are told. When a submitter seems overly willing to please a reviewer to get their code merged, there is a problem with your review process. As a submitter, you should carefully consider the suggestions made to your review, since you should know more about the new code than anyone else.

If you find yourself overly willing to implement changes in order to please your reviewer, step back and take the time to push back on what your reviewer is suggesting. While you should err on the side of incorporating feedback, it’s not helpful if you are blindly incorporating suggestions you don’t understand.

### #5 Thou shalt test before submitting a code review.

Sometimes submitters submit code that just doesn’t work. The code might have syntax errors or it might have an error that will affect the whole submission. To make sure the code being reviewed is relevant (and won’t need to be completely changed!), the submitter needs to test their code before starting a review. Testing is the only way you’ll know it actually works (yes, even if you’re writing Haskell!). This might be done through manual tests, unit tests, integration tests, end-to-end tests, etc., but there needs to be a way to prove that the code is runnable. A good way to think about this is, would it be okay if the code was approved and deployed immediately? If that makes you uncomfortable then you probably should not be submitting the review!

### _For Code Reviewers_

### #6 Thou shalt read every line of code.

For a code review to catch important bugs, the reviewer needs to understand everything the code is doing. Every line of code needs to be carefully read and examined. Yes, every single line! This is the only way to catch the important bugs and code inconsistencies. A good way of reviewing the code is having the reviewer ask themselves, “How is this line of code relevant to the goals of this submission?”. By asking this question, you’ll have to dig into the code to find what’s going on, or ask the submitter why the code is written the way it is. The best feedback on code often comes from a deep understanding of the code and finding better ways to solve the problem.

### #7 Thou shalt separate nitpicks and blockers.

When reviewing code, it’s often easy to pick out minor problems with the code. Maybe a variable name is not very good or maybe a function is put in the wrong place. These changes won’t actually have a big effect on code quality and won’t fix any bugs. These are nitpicks. They’re important and they should be fixed, but they shouldn’t block the merging of a pull request. Blockers on the other hand are problems with the code that will either cause bugs, create significant tech debt, or cause serious performance issues. Nitpicks usually only affect their current function or scope while blockers will have an effect beyond their current scope (the function, class or file in which they live). A way of understanding this distinction is by asking yourself: “Will the current version of this code cause significant negative consequences if merged?”. It the answer is “No”, then the comment is probably a nitpick and not a blocker.

Every comment to a pull request should be properly identified as a nitpick or as a blocker in order for the submitter to know how important it is. If a pull request is reviewed and only nitpicks are found, then the pull request should be approved. This distinction significantly improves the speed of code reviews since it only forces the submitter to address genuinely important issues. In order for nitpicks to also be addressed, the submitter must also be open and willing to address them, since this is a easy way for code quality to decrease significantly.

### #8 Thou shalt not hold a submitter hostage.

If your team is doing code reviews correctly, the reviewer has enough power to stop the merging of a pull request. This is important because, if a blocker is found the pull request should definitely not get merged. The power the reviewer should have is a good thing, but it can also be used for evil by having the submitter do things that are outside the scope of their pull request. Some examples of holding a submitter hostage are: blocking because of a code refactor, fixes to old code, or missing implementation outside the scope of the submission. Reviewers should only hold submitters accountable for what their pull requests aim to do and implement, and nothing else. If new bugs or missing features are found, then new issues and pull requests should be created for them.

Sometimes, a reviewer and a submitter will not be able to agree on something even after a healthy discussion on the subject. In these cases, the reviewer should respect the opinion of the submitter and not block the merging of a pull request based on something they disagree on. This situation is very uncommon, since most issues can be properly discussed, but it’s important to point out that the reviewer is ultimately helping the submitter and it’s the submitter’s responsibility to have a proper solution to the problem.

### #9 Thou shall review in under half a work day.

Perhaps the most frustrating thing about code reviews is actually getting a review! Not having a pull request reviewed promptly causes a submitter to switch contexts frequently and makes code iteration slower. For this reason, when asked to review, a reviewer should do so in less than half a work day (4 hours). This leaves enough time for a proper review to take place, while not forcing the submitter to context switch between multiple tasks. Ideally, the review process should not take more than one or two days (including feedback loop) for even the most complex pull requests.

### #10 Thou shalt take lengthy conversations face-to-face.

When a reviewer needs an explanation of a new feature, a nuanced question, or maybe a lengthy explanation into a certain part of the code, it’s better to take to have that conversation face-to-face. Having lengthier conversations face-to-face improves the speed at which the review process happens since everything happens synchronously (it also prevents lengthy 500 words explanations in pull requests!). Another positive is that it increases empathy between the submitter and reviewer. You’ll find that it’s easier to reach a compromise on any differences when you’re talking face-to-face than through the comment-reply system of a pull request. If you work in the same office as the rest of the engineering team other engineers might hear your conversation and contribute to the discussion, which often results in a more complete understanding of the issue.

### Conclusion

Code reviews can be stressful, but by following these commandments your team can have a common understanding of how code reviews should be conducted. These commandments will require discipline from both submitters and reviewers to work well, but the much smoother code review process will definitely be worth it.
