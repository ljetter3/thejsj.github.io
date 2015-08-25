require 'rubygems'
require 'bundler/setup'
require 'jekyll-import';

JekyllImport::Importers::Ghost.run({
  'dbfile'   => './ghost.db'
})
