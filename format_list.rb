#!/usr/bin/ruby

def convert_opcode(str)
  str.scan(/.{4}/)
     .map { |w| w.scan(/.{2}/).reverse.join.to_i(16).to_s(8).rjust(7, '0') }
end

INSTR_REGEX = /^(?<ln>\s+\d+)\s+(?<addr>[0-9a-f]+)\s+(?<opcode>[0-9A-F]+)\s+(?<text>.+)$/

stdout_next_line = false
dst_fname = ARGV[0] == '-p' ? 'build/ppu_subtitles.lst' : 'build/subtitles.lst'

File.open(dst_fname, 'a+') do |f|
  $stdin.read.each_line do |line|
    unless (matches = line.b.chomp.match(INSTR_REGEX))
      stdout_next_line = true if /^\s*\d+\s+;:bpt/.match?(line.b)
      next
    end

    print "#{matches[:addr].to_i(16).to_s(8).rjust(6, '0')}: " if stdout_next_line
    f.print "#{matches[:addr].to_i(16).to_s(8).rjust(6, '0')}: "

    instr = convert_opcode(matches[:opcode])
    opcode = instr.shift
    print "#{opcode}   " if stdout_next_line
    f.print "#{opcode}   "

    puts " #{matches[:text]}" if stdout_next_line
    f.puts "; #{matches[:text]}"

    while (arg = instr.shift)
      puts "#{' ' * 8}#{arg}" if stdout_next_line
      f.puts "#{' ' * 8}#{arg}"
    end

    stdout_next_line = false if stdout_next_line
  end
end
