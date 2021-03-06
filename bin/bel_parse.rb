#!/usr/bin/env ruby
# bel_parse: Show parsed objects from BEL content for debugging purposes.
#
# From BEL file
# usage: bel_parse -b file.bel
#
# From standard in
# usage: echo "<BEL DOCUMENT STRING>" | bel_parse

$:.unshift(File.join(File.expand_path(File.dirname(__FILE__)), '..', 'lib'))
require 'bel'
require 'optparse'

# additive String helpers
class String
  def rjust_relative(distance, string)
    rjust(distance - string.size + size)
  end
end

# setup and parse options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: bel_parse [options] [.bel file]"
  opts.on('-b', '--bel FILE', 'BEL file to parse.  STDIN (standard in) can also be used for BEL content.') do |bel|
    options[:bel] = bel
  end
end.parse!

if options[:bel] and not File.exists? options[:bel]
  $stderr.puts "No file for bel, #{options[:bel]}"
  exit 1
end

# read bel content
content =
if options[:bel]
  File.open(options[:bel], :external_encoding => 'UTF-8')
else
  $stdin
end

class Main

  def initialize(content)
    BEL::Script.parse(content) do |obj|
      object_desc = obj.class.name.split('::').last
      object_desc << obj.to_bel.rjust_relative(25, object_desc)
      puts object_desc
    end
  end
end
Main.new(content)
# vim: ts=2 sw=2:
# encoding: utf-8
