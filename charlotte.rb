#!/usr/bin/env ruby
=begin
https://github.com/takeiteasy/charlotte

The MIT License (MIT)

Copyright (c) 2022 George Watson

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
=end

require 'optparse'
require 'nokogiri'
require "selenium-webdriver"
require 'fcntl'
require 'open-uri'
require 'net/http'

valid_drivers=["chrome", "edge", "firefox", "ie", "safari"]
$opts = {
  :verbose => false,
  :files => [],
  :attrs => [],
  :url => nil,
  :driver => nil,
  :pageload => :normal,
  :timeout => nil,
  :headless => false,
  :proxy => nil,
  :selector => nil,
  :xpath => nil,
  :body => false
}
OptionParser.new do |o|
  o.banner = " Usage: `echo [TEXT] | #{$0}` or `#{$0} -f [FILE]` or `#{$0} -u [URL]`\n\n Description: A little spider to crawl the web!\n\n Example:\n\truby #{$0} --url http://www.example.com --selector 'p a' --attrs 'href'\n\t  => https://www.iana.org/domains/example\n\n"
  o.on '-h', '--help', 'Print help' do
    puts o
    exit
  end
  o.on '-v', '--verbose', 'Enable verbose logging' do
    $opts[:verbose] = true
  end
  o.on '-f', '--file A,B,C', Array, 'Read document(s) from path(s)' do |a|
    $opts[:files] += a
  end
  o.on '-u', '--url=URL', String, 'Download HTML/XML from URL' do |a|
    $opts[:url] = a
  end
  o.on '-d', '--driver=DRIVER', String, "Specify a WebDriver to use if you would like to use Selenium when using the `--url` option. Useful for websites that have automated `prove you are human` captchas. Or if you need to wait some something on the page to load. Valid drivers: #{valid_drivers.join(', ')}" do |a|
    aa = a.downcase
    unless valid_drivers.include? aa
      puts "ERROR! Invalid driver `#{a}`"
      puts o
      exit 1
    else
      $opts[:driver] = aa.to_sym
    end
  end
  o.on '-H', '--headless', "Enable `--headless` for Selenium WebDriver" do
    $opts[:headless] = true
  end
  o.on '-l', '--load-strategy', String, "Specify the page load strategy for Selenium WebDriver. Valid strats: `normal`, wait until page fully loads before returning. `eager` will wait until the DOM is loaded then return, other resources may still be loading. `none` doesn't block the WebDriver at all, `--timeout` option is required." do |a|
    aa = a.downcase
    unless ["normal", "eager", "none"].include? aa
      die "Unknown page load strategy: #{a}"
    else
      $opts[:pageload] << aa.to_sym
    end
  end
  o.on '-t', '--timeout=SECONDS', "Set the page load timeout when using `--url` (in seconds)" do |a|
    $opts[:timeout] = a.to_i
  end
  o.on '-p', '--proxy=ADDRESS', String, "Set a proxy for Selenium WebDriver" do |a|
    $opts[:proxy] = a
  end
  o.on '-s', '--selector=SELECTOR', String, 'Filter document(s) with a CSS selector' do |a|
    $opts[:selector] = a
  end
  o.on '-x', '--xpath=PATH', String, 'Filter document(s) with an XML XPath' do |a|
    $opts[:xpath] = a
  end
  o.on '-a', '--attrs A,B,C', Array, 'Specify any tag attributes to print' do |a|
    $opts[:attrs] += a
  end
  o.on '-b', '--body', 'When printing a matched result, only print the tag`s body' do
    $opts[:body] = true
  end
end.parse!

p opts if $opts[:verbose]

def read_stdin(timeout = 0.1)
  # Set STDIN to non-blocking mode
  flags = STDIN.fcntl Fcntl::F_GETFL, 0
  flags |= Fcntl::O_NONBLOCK
  STDIN.fcntl Fcntl::F_SETFL, flags

  # Set a timeout for the read operation
  io = IO::select [STDIN], [], [], timeout

  begin
    if not io.nil? and io[0].any?
      # Data is available, proceed with reading
      text = STDIN.read
      return text.chomp if text
    else
      # Timeout reached, no data available
      return nil
    end
  rescue Errno::EAGAIN
    # Expected exception for non-blocking reads, no data available
    return nil
  ensure
    # Restore original flags (optional)
    STDIN.fcntl Fcntl::F_SETFL, flags
  end
end

def die(msg="Unknown error!")
  STDERR.puts "ERROR! #{msg}"
  exit 1
end

def parse(d)
  begin
    Nokogiri::HTML.parse(d)
  rescue Nokogiri::XML::SyntaxError => e
    die e.message
  end
end

toparse = []

unless $opts[:url].nil?
  puts "* DOWNLOADING FROM #{$opts[:url]} ..." if $opts[:verbose]
  if $opts[:driver].nil?
    begin
      response = nil
      if $opts[:timeout].nil?
        response = URI.open($opts[:url])
      else
        Timeout.timeout($opts[:timeout]) do
          response = URI.open($opts[:url])
        end
      end
      die if response.nil?
      toparse << response.read
    rescue Timeout::Error, SocketError, OpenURI::HTTPError => e
      die e.message
    ensure
      response.close if response
    end
  else
    puts "* USING SELENIUM (#{$opts[:driver]}) ..."
    options = case $opts[:driver]
              when :chrome
                Selenium::WebDriver::Options.chrome
              when :edge
                Selenium::WebDriver::Options.edge
              when :firefox
                Selenium::WebDriver::Options.firefox
              when :ie
                Selenium::WebDriver::Options.ie
              when :safari
                Selenium::WebDriver::Options.safari
              end
    options.page_load_strategy = $opts[:pageload]
    if $opts[:pageload] == :none
      die "`--load-strategy` option set to `:none` with no timeout" if $opts[:timeout].nil?
    end
    options.timeouts = {page_load: $opts[:timeout]} unless $opts[:timeout].nil?
    options.proxy = Selenium::WebDriver::Proxy.new(http: $opts[:proxy]) unless $opts[:proxy].nil?
    options.add_argument('--headless') if $opts[:headless]
    driver = Selenium::WebDriver.for $opts[:driver], options: options
    driver.get $opts[:url]
    sleep($opts[:timeout]) if $opts[:pageload] == :none
    toparse << driver.page_source
    driver.quit
  end
end

$opts[:files].each do |file|
  puts "* READING FROM FILE #{file} ..."
  begin
    text = File.read(file)
    toparse << text
  rescue Errno::ENOENT => e
    die e.message
  rescue
    die
  end
end

text = read_stdin
unless text.nil?
  toparse << text
  puts "* FOUND TEXT FROM STDIN ..." if $opts[:verbose]
end

if toparse.empty?
  puts "Nothing to do! Type `ruby #{$0} --help` for usage"
  exit 0
else
  puts "* FOUND #{toparse.length} DOCUMENTS TO PARSE" if $opts[:verbose]
end

def print_elm_attr(elm)
  elm.attribute_nodes.each do |attr|
    if $opts[:attrs].include? attr.name
      puts attr.value
    end
  end
end

def print_elm(elm)
  if $opts[:body]
    elm.children.each do |e|
      if $opts[:attrs].empty?
        puts e
      else
        print_elm_attr e
      end
    end
  else
    if $opts[:attrs].empty?
      puts elm
    else
      print_elm_attr elm
    end
  end
end

toparse.each do |p|
  doc = parse(p)
  if $opts[:xpath] or $opts[:selector]
    if $opts[:xpath]
      x = doc.xpath $opts[:xpath]
      unless x.empty?
        x.each do |xx|
          print_elm xx
        end
      end
    end
    if $opts[:selector]
      c = doc.css $opts[:selector]
      unless c.empty?
        c.each do |cc|
          print_elm cc
        end
      end
    end
  else
    if $opts[:body]
      puts doc.at('body').inner_html
    else
      puts doc.to_html
    end
  end
end
