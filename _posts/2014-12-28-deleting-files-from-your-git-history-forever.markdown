---
layout: post
title: Deleting Files From Your GIT history FOREVER!
date: 2014-12-28 10:10:19.000000000 -08:00
---
We all make mistakes. That's life. 

Sometimes I use `git add -A`. It's terrible, I know. 

Sometimes, I commit 200mb TIFFs or `.DS_Store` files or maybe even [full databases](https://github.com/thejsj/Blog/blob/45713d3ff2118cc140b7cf25dccb147379868cdf/README.md).

Sometimes I even commit passwords and other sensitive data!

Thankfully, you can fix that. When you want to delete a file from your repo and delete all references to it in your git history, you can use the following command: 

```
git filter-branch --force --index-filter \
      'git rm --cached --ignore-unmatch NAME_OF_YOUR_FILE' \
      --prune-empty --tag-name-filter cat -- --all
```
This will basically go through all the commits in your repo's history and rewrite them to remove that file. In my blog's repo, I included the database and images for a while. I ran this command against them and removed them completely. These files should have never been there in the first place, so it's ok to remove them from history. 

Obviously, you need to be VERY careful with this command. It can be very dangerous and should only be used in very specific scenarios. I would only use it to delete binary files or files that have never been modified by the user (.DS_Store and such). I think it's particularly useful for when big files are accidentally committed and bloat the size of you repo.

I've made this into a bash function and included it in my `~/.bash_profile`. Here's how that looks:

```
git-remove-all() {
  git filter-branch --force --index-filter \
      'git rm --cached --ignore-unmatch $1' \
      --prune-empty --tag-name-filter cat -- --all
}
```
[Here's a GitHub article on deleting sensitive data](https://help.github.com/articles/remove-sensitive-data/)
