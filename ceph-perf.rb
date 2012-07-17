#!/usr/bin/ruby
require 'socket'
require 'json'

ceph_sock_dir = ARGV[0]
host = ARGV[1]
port = ARGV[2]

Dir.foreach(ceph_sock_dir) do |file|
  next unless file.match(".*\.asok")
  jschema = %x{ ceph --admin-daemon #{ceph_sock_dir}/#{file} perf schema}
  jdump = %x{ ceph --admin-daemon #{ceph_sock_dir}/#{file} perf dump}
  
  collections = JSON.parse(jdump)
  schema = JSON.parse(jschema)

  /(ceph-osd\.\d*)\.asok/ =~ file
  base = $1

  stat_sock = UDPSocket.new
  schema.each_key do |collection|
    schema[collection].each_key do |metric|
      case schema[collection][metric]['type']
      when 2
        puts "#{base}.#{collection}.#{metric}:#{collections[collection][metric]}|g" 
        stat_sock.send("#{base}.#{collection}.#{metric}:#{collections[collection][metric]}|g", 0, host, port)
      when 5
        puts "#{base}.#{collection}.#{metric}.avgcount:#{collections[collection][metric]['avgcount']}|c"
        stat_sock.send("#{base}.#{collection}.#{metric}.avgcount:#{collections[collection][metric]['avgcount']}|c", 0, host, port)
        puts "#{base}.#{collection}.#{metric}.sum:#{collections[collection][metric]['sum']}|c"
        stat_sock.send("#{base}.#{collection}.#{metric}.sum:#{collections[collection][metric]['sum']}|c", 0, host, port)
      when 10
        puts "#{base}.#{collection}.#{metric}:#{collections[collection][metric]}|c" 
        stat_sock.send("#{base}.#{collection}.#{metric}:#{collections[collection][metric]}|c", 0, host, port)
      end
    end
  end
end
