#!/usr/bin/ruby

# Скрипт прописывает размеры бинарных файлов и их начальные блоки на диске
# Для этого необходимы:
# FILESLIST_FILENAME - список файлов
# MAP_FILENAME - карта UPDATED_FILENAME созданная ликовщиком
# UPDATED_FILENAME - файл в который будут прописаны метаданные
#                    должен содеражать метки, соответствующие файлам
#                    из FILESLIST_FILENAME
# ADDR - стартовый адрес целевого файла

require 'optparse'
require 'pathname'
require_relative 'dsk_image_constants'

options = Struct.new(:fileslist_filename, :map_filename, :updated_filename, :entry).new

OptionParser.new do |opts|
  opts.banner = 'Usage: ' \
                'update_disk_map.rb FILESLIST_FILENAME MAP_FILENAME UPDATED_FILENAME --entry n'
  options.fileslist_filename = opts.default_argv[0]
  options.map_filename = opts.default_argv[1]
  options.updated_filename = opts.default_argv[2]

  opts.on('-e ADDR', '--entry ADDR", "binary file entry point') do |n|
    options.entry = n.to_i
  end
end.parse!

fileslist = File.readlines(options.fileslist_filename, chomp: true)

metadata = fileslist.map do |pathname|
  basename = Pathname.new(pathname).basename.to_s

  [basename, { address: 0, size: File.size(pathname) }]
end.to_h

# Получим адреса меток из мап-файла
File.read(options.map_filename).each_line do |line|
  fileslist.each do |pathname|
    basename = Pathname.new(pathname).basename.to_s

    if /0x\p{XDigit}{16}\s+#{basename}/.match?(line)
      metadata[basename].update(address: line[/0x\p{XDigit}{16}/].to_i(16))
    end
  end
end

bootstrap_bin = File.binread(options.updated_filename).unpack('v*')
if File.exist?("#{options.updated_filename}._")
  options.entry = File.read("#{options.updated_filename}._").split(',').first.to_i
end

current_block_num = 0

metadata.each_value do |data|
  address = data[:address]
  size = data[:size]

  unless address.zero?
    offset = address / 2
    offset -= options.entry / 2 unless options.entry.nil?

    bootstrap_bin[offset + 1] = (size + 1) / 2
    bootstrap_bin[offset + 2] = current_block_num
  end

  current_block_num += (size + 511) / 512
end

File.binwrite(options.updated_filename, bootstrap_bin.pack('v*'))
