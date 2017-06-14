#!/bin/env ruby

require 'socket'

def usage_exit
  puts <<~EOL
    cmd control name [value]
    cmd timer name
  EOL
  exit
end


if ARGV.length < 3
  usage_exit
end

dst = ARGV.shift
ip, port = if dst =~ /[0-9.]+:[0-9]+/
             ip, port = dst.split(/:/)
             [ip, port.to_i]
           else
             File.open(dst) do |f|
               ip, port = f.gets.split(/:/)
               [ip, port.to_i]
             end
           end

p ip
p port

socket = UDPSocket.new
socket.connect(ip, port)

command_name = ARGV.shift
case command_name
when 'timer'
  data = "\x01" + ARGV.shift.to_s
  socket.send data, 0
when 'control'
  data = "\x02" + ARGV.shift
  if value = ARGV.shift
    data += "\x00" + [value.to_i].pack('C')
  end
  socket.send data, 0
end



