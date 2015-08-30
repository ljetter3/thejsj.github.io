# Jorge's Blog

## Setup

1. Install Ruby, if necessary

1. Install bundler:

```bash
sudo gem install bundler
```

1. Install gems using bundler

```bash
bundle install
```

## Building Site

After, you've setup bundler and jekyll, you can now build the site:

```bash
bundle exec jekyll build
```

Alternatively, you can start listening for changes in your files and serve your
site on `localhost:4000`.

```bash
bundle exec jekyll serve
```

## Importing from Ghost

If you want to reimport the post from the Ghost database, you can run the 
following command. This presume that you have a Ghost SQLite3 database named
`Ghost.db`. This shouldn't really be necessary though, since posts have been
imported and gone through significant changes.

```
bundle exec ruby import.rb
```

## Credit

Based on kasper, which is based on the original Ghost theme.
