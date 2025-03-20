# frozen_string_literal: true

# The code is taken from
# https://github.com/nzeemin/ukncbtl-utils/blob/master/Sav2Cartridge/Sav2Cart.cpp
# One can write C in any language)

module Encoders
  module Rle
    extend self

    def call(src, debug: false)
      # src = src.bytes
      buffer = []

      seq_block_offset = 0
      seq_block_size = 1
      var_block_offset = 0
      var_block_size = 1
      previous_byte  = src[0]
      coded_size_total = 0

      1.upto(src.length) do |current_offset|
        current_byte = if current_offset < src.length
                         src[current_offset]
                       else
                         previous_byte
                       end

        if (current_offset == src.length) ||
           (current_byte != previous_byte && seq_block_size > 31) ||
           (current_byte != previous_byte && seq_block_size > 1 && previous_byte.zero?) ||
           (current_byte != previous_byte && seq_block_size > 1 && previous_byte == 0xFF) ||
           (seq_block_size == 0x1FFF || var_block_size - seq_block_size == 0x1FFF)
          if var_block_offset < seq_block_offset
            # Special case at the end of input stream
            var_size = if current_offset == src.length && seq_block_size < 2
                         var_block_size
                       else
                         var_block_size - seq_block_size
                       end

            coded_size = var_size + (var_size < 256 / 8 ? 1 : 2)
            if debug
              format("RLE  at\t%<offset>06o\tVAR  %<var_size>06o  %<coded_size>06o\t",
                     offset: var_block_offset + 512,
                     var_size:,
                     coded_size:)
            end
            coded_size_total += coded_size

            flag_byte = 0x40
            if var_size < 256 / 8
              format('%02x ', (flag_byte | var_size)) if debug
              buffer << (flag_byte | var_size)
            else
              format('%02x ', (0x80 | flag_byte | ((var_size & 0x1F00) >> 8))) if debug
              buffer << (0x80 | flag_byte | ((var_size & 0x1F00) >> 8))
              format('%02x ', (var_size & 0xFF)) if debug
              buffer << (var_size & 0xFF)
            end

            var_block_offset.upto(var_size - 1) do |offset|
              puts src[offset] if debug
              buffer << src[offset]
            end

            puts if debug
          end

          if (var_block_offset < seq_block_offset && seq_block_size > 1) ||
             (var_block_offset == seq_block_offset && var_block_size == seq_block_size)
            coded_size = seq_block_size < 256 / 8 ? 1 : 2
            coded_size += previous_byte.zero? || previous_byte == 255 ? 0 : 1

            if debug
              format("RLE  at\t%<offset>06o\tSEQ  %<seq_block_size>06o  " \
                     "%<coded_size>06o\t%<previous_byte>02x\n",
                     offset: seq_block_offset + 512,
                     seq_block_size:,
                     coded_size:,
                     previous_byte:)
            end

            coded_size_total += coded_size
            flag_byte = if previous_byte.zero?
                          0
                        else
                          previous_byte == 255 ? 0x60 : 0x20
                        end

            if seq_block_size < 256 / 8
              buffer << (flag_byte | seq_block_size)
            else
              buffer << (0x80 | flag_byte | ((seq_block_size & 0x1F00) >> 8))
              buffer << (seq_block_size & 0xFF)
            end

            buffer << previous_byte unless [0, 255].include?(previous_byte)
          end

          seq_block_offset = current_offset
          var_block_offset = current_offset
          seq_block_size = 1
          var_block_size = 1

          previous_byte = current_byte
          next
        end

        var_block_size += 1

        if current_byte == previous_byte
          seq_block_size += 1
        else
          seq_block_size = 1
          seq_block_offset = current_offset
        end

        previous_byte = current_byte
      end

      ratio = (buffer.count * 100.0 / src.length).round(2)
      times = (src.length.to_f / buffer.count).round(2)
      puts "RLE input size #{src.length} bytes"
      puts "RLE output size #{buffer.count} bytes (#{ratio}% of original, #{times}x smaller)"

      buffer.pack('C*')
    end
  end
end

src = File.binread("sound/Rushin' In.adl").bytes

src_even = []
src_odd = []
(src.length / 2 + 1).times { |i| src_even << src[i * 2] }
(src.length / 2 + 1).times { |i| src_odd << src[i * 2 + 1] }

File.binwrite('rushing.adl.even', Encoders::Rle.call(src_even, debug: true))
File.binwrite('rushing.adl.odd', Encoders::Rle.call(src_odd, debug: true))
