puts "__FILE__ == #{__FILE__}"
puts "File.expand_path(__FILE__) == #{File.expand_path(__FILE__)}"
puts "File.expand_path('..') == #{File.expand_path('..')}"
puts "File.expand_path('..', __FILE__) == #{File.expand_path(__dir__)}"
puts "File.expand_path('.') == #{File.expand_path('.')}"
puts "File.expand_path(__dir__) == #{File.expand_path(__dir__)}"

puts "File.expand_path(__FILE__, '..') == #{File.expand_path(__FILE__, '..')}"
