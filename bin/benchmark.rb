#!/usr/bin/env ruby

require "net/http"
require "uri"

# set this to the IP fleet returns for the nginx unit
nginx_url = ARGV[0]

raise "ERROR: A valid web URL must be supplied\nUsage: benchmark.rb <URL>\n" unless nginx_url

puts "Accessing #{nginx_url}\n"

i = 0
print "loop "
while true do
    i = i + 1
    print "#{i} "
    threads = []

    8.times do
        threads << Thread.new do
            Net::HTTP.get_response(URI.parse(nginx_url))
        end
    end

    threads.join

    sleep rand(2)
end
