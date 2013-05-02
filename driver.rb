# encoding: utf-8
require 'rubygems'

$LOAD_PATH.unshift(File.dirname(__FILE__)) unless $LOAD_PATH.include?(File.dirname(__FILE__))

Parser_exec = "#{Dir.pwd}/test"
Target_Dir = ARGV[0]

def del_file(fn)
  if File.exist?(fn)
    File.delete(fn)
  end
end

def parse()
  files = nil
  Dir.chdir(Target_Dir) do
    output_dir = "#{Dir.pwd}/result"
    Dir.mkdir("#{Dir.pwd}/result") unless Dir.exist?("#{Dir.pwd}/result")

    files = Dir.glob('*.cs')
    files.each do |f|
      output_fn = "#{output_dir}/#{f.split(/\./)[0]}.rl"
      system "#{Parser_exec} #{f} #{output_fn}"
    end
  end
end

del_file("fail.log")
del_file("succ.log")
puts "Start parsing..."
parse()
puts "Finished!"
