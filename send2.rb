#!/usr/bin/env ruby

require 'socket'

sock = UDPSocket.new
sock.bind '127.0.0.1', 50003
sock.connect '127.0.0.1', 50002

sock.send "ab", 0
sleep 0.3

