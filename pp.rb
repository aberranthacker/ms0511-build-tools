# frozen_string_literal: true

text = File.read(ARGV[0])

last_global_label = ''
local_labels = text.scan(/(?<=^|\s)(\.[a-z_]+\b):/).flatten.uniq

text.lines.each do |line|
  comment_start_idx = line.index(';')
  next if comment_start_idx == 0 # rubocop:disable Style/NumericPredicate

  line = line[0...comment_start_idx].rstrip
  next if line.empty?

  label = line[/(^|\s)([A-Za-z][A-Za-z_.]*):/, 2]
  last_global_label = label unless label.nil?

  line_local_labels = line.scan(/(?<=^|\s|,)(\.[a-z_]+\b)/).flatten.uniq
  line_local_labels &= local_labels
  line_local_labels.map! { "\\#{_1}" }

  line_local_labels.each do |local_label|
    line.gsub!(/(^|\s)(#{local_label}\b)/, "\\1#{last_global_label}\\2")
  end

  puts line
end
