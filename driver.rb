# encoding: utf-8
require 'rubygems'
require 'parallel'

$LOAD_PATH.unshift(File.dirname(__FILE__)) unless $LOAD_PATH.include?(File.dirname(__FILE__))

Parser_exec = "#{Dir.pwd}/test.exe"
Target_dir = ARGV[0]

Fails_log = "#{Dir.pwd}/fails.log"

$fn_arr = Array.new

def get_cs_fn(entry)
  Dir.chdir(entry) do
    files = Dir.glob('*.cs')
    files.each do |f|
      $fn_arr.push("#{Dir.pwd}/#{f}")
    end
  end
  Dir.foreach(entry) do |e|
    next if '.' == e or '..' == e
    Dir.chdir(entry) do 
      if File.directory?(e)
        get_cs_fn(e)
      end
    end
  end
end

def parse_file(fn)
  rule_fn = "#{fn.split(/\./)[0]}.rl"
  system "#{Parser_exec} \"#{fn}\" \"#{rule_fn}\" #{Fails_log}"
end

File.delete("fail.log") if File.exist?("fail.log")
File.delete("succ.log") if File.exist?("succ.log")

puts "Start parsing..."
puts "Collecting cs source files..."
get_cs_fn(Target_dir)

puts "Generating rule files..."
Parallel.map($fn_arr) do |fn|
  parse_file(fn)
end 

#$fn_arr.each do |fn|
  #parse_file(fn)
#end

puts "Finished!"
