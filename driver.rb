# encoding: utf-8
require 'rubygems'
require 'parallel'

$LOAD_PATH.unshift(File.dirname(__FILE__)) unless $LOAD_PATH.include?(File.dirname(__FILE__))

Parser_exec = "#{Dir.pwd}/test.exe"
Target_dir = ARGV[0]

Fails_log = "#{Dir.pwd}/fails.log"

$fn_arr = Array.new


$client_name = ""
puts "Need p4 client name" unless File.exist?("p4Client.txt")
File.open("p4Client.txt") { |f| $client_name = f.readlines[0].chop }

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

def get_rule_fn(fn)
  rl_fn = fn[0..fn.size-3] + "rl"
  rl_fn
end

def gen_rule(fn)
  rule_fn = get_rule_fn(fn)
  system "#{Parser_exec} \"#{fn}\" \"#{rule_fn}\" #{Fails_log}"
end

def get_p4_path(fn)
  # stupid op!!!
  "/" + fn[30, fn.length-30]
end

def get_op_pos(op_line, max_line, delta)
  if op_line < max_line
    return op_line - 1
  else
    return op_line + delta - 1
  end
end

def modify_file(fn, rl)
  # for line count
  delta = 0
  handled_rm_lines = []
  max_line = 0;
  puts "Rule file doesn't exist:#{rl}." unless File.exist?(rl)
  puts "Source file doesn't exist:#{fn}." unless File.exist?(fn)

  src_file = File.open(fn, "r")
  src_lines = src_file.readlines
  src_file.close

  File.open(rl, "r") do |rules|
    rl_lines = rules.readlines
    return if rl_lines.empty?

    # Perforce
    cmd = "p4.exe -c #{$client_name} " + "edit \"#{get_p4_path(fn)}\""
    return unless system cmd

    log_file = File.open("log.txt", "a+")
    
    rl_lines.each do |rule|
      line = rule.split(/\|/)

      op_line = line[1].to_i

      if "-" == line[0]
        #src_lines.delete_at(op_line + delta - 1)
        next if handled_rm_lines.include?(op_line)
        src_lines.delete_at(get_op_pos(op_line, max_line, delta))
        delta -= 1;
        handled_rm_lines << op_line
      elsif "+^" == line[0]
        #insert_pos = line[1].to_i + delta - 1
        insert_pos = get_op_pos(line[1].to_i, max_line, delta)
        # protection!
        if "{" != src_lines[insert_pos - 1].chop.lstrip.rstrip
          puts "Nasty code style for cs file:#{fn}, Line:#{line[1]}\n"
          log_file.write("Nasty code style for cs file:#{fn}, Line:#{line[1]}\n")
          return
        end
        src_lines.insert(insert_pos, "            _transaction_.Start(\"#{line[2].chop}\");\r\n")
        src_lines.insert(insert_pos, "         {\r\n")
        src_lines.insert(insert_pos, "         using (Transaction _transaction_ = new Transaction(RevitDoc))\r\n")
        delta += 3
      elsif "+$" == line[0]
        #insert_pos = line[1].to_i + delta - 1
        insert_pos = get_op_pos(line[1].to_i, max_line, delta)
        src_lines.insert(insert_pos, "         }\r\n")
        if 2 == line[2].to_i
          src_lines.insert(insert_pos, "            _transaction_.RollBack();\r\n")
        elsif 0 == line[2].to_i
          src_lines.insert(insert_pos, "            _transaction_.Commit();\r\n")
        else
          puts "Error transection mode:#{line[2]}"
        end
        delta += 2
      else
        puts "Error while parsing rule:#{rule}."
      end

      max_line = op_line if op_line > max_line
    end
  end
  
  File.open(fn, "w+") do |f|
    src_lines.each { |line| f.write(line) }
  end

end

File.delete("fail.log") if File.exist?("fail.log")
File.delete("succ.log") if File.exist?("succ.log")
File.delete("log.txt") if File.exist?("log.txt")

puts "Start parsing..."
puts "Collecting cs source files..."
get_cs_fn(Target_dir)

puts "Generating rule files..."
Parallel.map($fn_arr) do |fn|
  gen_rule(fn)
end 

puts "Modifying files..."
Parallel.map($fn_arr) do |fn|
  rule_fn = get_rule_fn(fn)
  modify_file(fn, rule_fn)
end

#gen_rule("test.cs")
#modify_file("test.cs", "test.rl")

puts "Finished!"
