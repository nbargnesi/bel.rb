# Load core objects
require_relative './lib_bel'
require_relative 'bel/completion'
require_relative 'bel/language'
require_relative 'bel/namespace'
include BEL::Language
include BEL::Namespace

module BEL
  autoload :Script,    "#{File.dirname(__FILE__)}/bel/script"
  autoload :RDF,       "#{File.dirname(__FILE__)}/bel/rdf"

  require_relative './features.rb'
  require_relative './util.rb'
end

begin
  RUBY_VERSION =~ /(\d+.\d+)/
  require '#{$1}/bel_ext'
rescue LoadError
  require 'bel_ext'
end

# vim: ts=2 sw=2:
# encoding: utf-8
