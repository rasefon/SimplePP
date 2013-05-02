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

def gen_rule(fn)
  rule_fn = "#{fn.split(/\./)[0]}.rl"
  system "#{Parser_exec} \"#{fn}\" \"#{rule_fn}\" #{Fails_log}"
end

def modify_file(fn, rl)
  # for line count
  delta = 0
  handled_lines = []
  puts "Rule file doesn't exist:#{rl}." unless File.exist?(rl)
  puts "Source file doesn't exist:#{fn}." unless File.exist?(fn)

  src_file = File.open(fn, "r")
  src_lines = src_file.readlines
  src_file.close

  File.open(rl, "r") do |rules|
    return if rules.readlines.empty?
    rules.readlines.each do |rule|
      line = rule.split(/\|/)

      op_line = line[1].to_i
      next if handled_lines.include?(op_line)

      handled_lines << op_line

      if "-" == line[0]
        src_lines.delete_at(op_line + delta - 1)
        delta -= 1;
      elsif "+^" == line[0]
        insert_pos = line[1].to_i + delta - 1
        # protection!
        if "{" != src_lines[insert_pos - 1].chop.lstrip.rstrip
          puts "Nasty code style!"
          return
        end
        src_lines.insert(insert_pos, "transaction.Start(\"#{line[2].chop}\");\r\n")
        src_lines.insert(insert_pos, "{\r\n")
        src_lines.insert(insert_pos, "using (Transaction transaction = new Transaction(RevitDoc))\r\n")
        delta += 3
      elsif "+$" == line[0]
        insert_pos = line[1].to_i + delta - 1
        src_lines.insert(insert_pos, "}\r\n")
        if 2 == line[2].to_i
          src_lines.insert(insert_pos, "transaction.RollBack();\r\n")
        elsif 0 == line[2].to_i
          src_lines.insert(insert_pos, "transaction.Commit();\r\n")
        else
          puts "Error transection mode."
        end
        delta += 2
      else
        puts "Error while parsing rule:#{rule}."
      end
    end
  end
  
  File.open(fn, "w+") do |f|
    src_lines.each { |line| f.write(line) }
  end

end

File.delete("fail.log") if File.exist?("fail.log")
File.delete("succ.log") if File.exist?("succ.log")

puts "Start parsing..."
puts "Collecting cs source files..."
get_cs_fn(Target_dir)

puts "Generating rule files..."
Parallel.map($fn_arr) do |fn|
  gen_rule(fn)
end 

puts "Modifying files..."
Parallel.map($fn_arr) do |fn|
  rule_fn = "#{fn.split(/\./)[0]}.rl"
  modify_file(fn, rule_fn)
end

puts "Finished!"
