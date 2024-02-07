#!/usr/bin/env ruby
=begin
https://github.com/takeiteasy/tools
Description: Simple CSS/XPath selector searcher, built for web scraping
Depends on slop + nokogiri, inspired by https://github.com/ericchiang/pup

Version 2, December 2004

Copyright (C) 2022 George Watson [gigolo@hotmail.co.uk]

Everyone is permitted to copy and distribute verbatim or modified
copies of this license document, and changing it is allowed as long
as the name is changed.

DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE TERMS AND CONDITIONS FOR
COPYING, DISTRIBUTION AND MODIFICATION

0. You just DO WHAT THE FUCK YOU WANT TO.
=end

require 'optparse'
require 'nokogiri'

$attrs = []
$files = []
$xpath = false
$printElements = false
$printLength = false
OptionParser.new do |o|
    o.banner = " Usage: #{$0} [flags] [selector] [-f a:b:c] [-a href:title:src]"
    o.on '-h', '--help', 'Print help' do
        puts o
        exit
    end
    o.on '-f', '--files A,B,C', Array, 'Pass list of HTML/XML files' do |a|
        $files += a
    end
    o.on '-a', '--attrs A,B,C', Array, 'Specify an attributes to print' do |a|
        $attrs += a
    end
    o.on '-x', '--xpath', 'Specify XPath selector' do
        $xpath = true
    end
    o.on '-t', '--text', 'Output content of elements' do
        $printElements = true
    end
    o.on '-l', '--length', 'Output number of elements' do
        $printLength = true
    end
end.parse!

unless ARGV.length == 1
  puts "ERROR: No CSS selector or XPath supplied\n"
  exit 1
end

$selector = ARGV[0].split(',').map(&:strip)
$type = $xpath ? :xpath : :css

def doit x
    length = 0
    $selector.each do |s|
        y = Nokogiri::HTML.parse(x).send($type, s)
        length += y.length
        next if $printLength
        y.each do |z|
            if not $attrs.empty?
                $opts[:attr].each do |a|
                    b = z.attribute(a)
                    unless b.to_s.to_s.strip.empty?
                        puts b
                    end
                end
            elsif $printElements
                puts z.content unless z.content.empty?
            else
                o = z.to_s.split("\n").map(&:strip)
                puts o.join() unless o.empty?
            end
        end
    end
    return length
end

length = 0
if not $files.empty?
    $files.each do |x|
        length = doit File.read(x)
    end
else
    length = doit STDIN.readlines.join()
end

puts length if $printLength

