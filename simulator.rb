#!/bin/env ruby

require 'logger'
require 'socket'
require 'pp'
require 'awesome_print'

# event exception
class Transit < StandardError
  attr_accessor :before_state, :after_state
end

# receiver
class SignalReceiver < UDPSocket
#  def read_nonblock(*args)
#  def recv_nonblock(*args)
   def recv
    raw_data = super(65535)
    [raw_data, Simulator::EventKind::Signal]
  end
end

# internal event receiver
class EventReceiver < UDPSocket
#  def read_nonblock(*args)
#  def recv_nonblock(*args)
  def recv
    raw_data = super(65535)
    kind = raw_data[0].unpack('C').shift
    data = raw_data[1..-1]
    [data, kind]
  end
end

# State-Event-Action table
#
# @__states = {
#   initial: {
#     in_action: Proc,
#     out_action: Proc,
#     receives: [
#       {peer_name: Symbol|nil, cond: Proc, action: Proc},
#       ...
#     ],
#     timers: {
#       Symbol: Proc,
#       ...
#     },
#     controls: {
#       [Symbol, Numeric] => Proc,
#       ...
#     }
#   },
#   hoge: {
#   },
#   ...
# }
#

class Simulator
  module EventKind
    Signal     = 0
    Timer      = 1
    Control    = 2
  end
  # event packet structure 
  #   Signal
  #     0      : 0
  #     1..-1  : signal data (Binary String)
  #
  #   Timer
  #     0      : 1
  #     2..-1  : timer name (String)
  #
  #   Control "\x2(controlname)[\x0[controlvalue]]"
  #     0      : 2
  #     1...n  : control name (String)
  #     n      : separator "\x0", optional
  #     n+1    : control value, 1oct, optional

  def initialize(sig_receiver, proto_klass, ev_receiver, logger)
    @logger = logger

    add_peer(sig_receiver, nil, proto_klass)
    @__ev_receiver = ev_receiver
    @__current_state = :initial

    @__active_timers = {}

    @logger.info "event socket: #{ev_receiver.addr[3]}:#{ev_receiver.addr[1]}"
  end



  #--------------------------
  # Action Triggers
  #--------------------------
  def in_action(&block)
    @__state[:in_action] = block
  end

  def out_action(&block)
    @__state[:out_action] = block
  end

  def receive(cond, peer_name = nil, &block)
    @__state[:receives] << {peer_name: peer_name, cond: cond, action: block}
  end

  def expire(timer_name, &block)
    @__state[:timers][timer_name] = block
  end

  def control(control_name, value = nil, &block)
    key = value ? [control_name, value] : [control_name]
    @__state[:controls][key] = block
  end

  #--------------------------
  # in action functios
  #--------------------------
  def P(&block)
    Proc.new &block
  end

  def send(*args)
    name, sig = if args.length == 2
                  args
                else
                  [nil, *args]
                end
    @logger.info "send: #{name}, #{sig.each_byte.map{|x| "%02x" % x}.join}"

    # @__peers[sig_receiver] = { name: name.to_sym, proto_klass: proto_klass }
    sock, _ = @__peers.find{|_, peer_info| peer_info[:name] == name} 

    sock.send sig, 0
  end

  def transit(name)
    @logger.info "transit: #{@__current_state} -> #{name}"

    transit = Transit.new
    transit.before_state = @__current_state
    transit.after_state = name

    raise transit
  end

  def start_timer(timer_name, time)
    @logger.info "start timer: #{timer_name} #{time}"

    stop_active_timer!(@__active_timers, timer_name)

    _, port, _, ip = @__ev_receiver.addr
    th = Thread.new(timer_name, time, ip, port) do |timer_name, time|
      data = [EventKind::Timer].pack('C') + timer_name.to_s
      sleep time
      UDPSocket.new.send(data, 0, ip, port)
    end
    @__active_timers[timer_name] = th
  end

  def stop_timer(timer_name)
    @logger.info "stop timer: #{timer_name}"

    stop_active_timer!(@__active_timers, timer_name)
  end

  #--------------------------
  # support functions
  #--------------------------
  def define(block)
    self.instance_eval &block
  end



  def add_state(state_name, &block)
    @__states ||= {}

    @__state = { receives: [], timers: {}, controls: {}}
    self.instance_eval &block

    @__states[state_name] = @__state
  end

  def add_peer(sig_receiver, name, proto_klass)
    name_msg = name ? ":#{name}" : ""
    @logger.info "signal socket: #{sig_receiver.addr[3]}:#{sig_receiver.addr[1]} #{name_msg} #{proto_klass.to_s}"

    @__peers ||= {}
    @__peers[sig_receiver] = { name: name&.to_sym, proto_klass: proto_klass }
  end

  def event_loop
    # do :initial :in_action
    begin
      do_in_action(@__states, @__current_state)
    rescue Transit => e
      do_out_action(@__states, @__current_state)
      @__current_state = e.after_state
      do_in_action(@__states, @__current_state)
    end

    loop do
      begin
        socks, _ = IO::select [*@__peers.keys, @__ev_receiver]
        sock = socks.first

        signal, event_kind = sock.recv

        if sock == @__ev_receiver
          peer_name = nil
        else
          peer_info = @__peers[sock]
          peer_name = peer_info[:name]
          @sig = peer_info[:proto_klass].from_bytes(signal, *@decode_params)
        end

        events = @__states[@__current_state]

        if action = fetch_action(events, event_kind, peer_name, signal)
          self.instance_eval(&action)
        else
          @logger.info "!!! no match event: #{signal.each_byte.map{|x| "%02x" % x}.join }"
        end
      rescue Transit => e
        do_out_action(@__states, @__current_state)
        @__current_state = e.after_state
        do_in_action(@__states, @__current_state)
      end
    end
  end


  private

  def fetch_action(events, event_kind, peer_name, signal)
    case event_kind
    when EventKind::Signal
      return fetch_signal_action(events[:receives], peer_name, signal)
    when EventKind::Timer
      return fetch_timer_action(events[:timers], signal)
    when EventKind::Control
      return fetch_control_action(events[:controls], signal)
    end
    nil
  end

  def fetch_signal_action(events, peer_name, signal)
    target_event =
      events.find{|event|
        event[:peer_name] == peer_name &&
        self.instance_exec(& event[:cond])
      }

    from_msg = peer_name ? "from :#{peer_name}" : ""
    target_event_line_msg = target_event ? "line #{target_event[:cond].source_location[1]}" : ""
    @logger.info "signal event occured: #{from_msg} #{target_event_line_msg}"

    return nil unless target_event

    target_event[:action]
  end

  def fetch_timer_action(events, signal)
    timer_name = signal.to_sym
    @logger.info "timer event occured: #{timer_name}"
    events[timer_name]
  end

  def fetch_control_action(events, signal)
    control_name, value = signal.split("\x0")
    @logger.info "control event occured: #{control_name} #{value ? value.unpack('C').shift : ''}"
    key = if value
            [control_name.to_sym, value.unpack('C').shift]
          else
            [control_name.to_sym]
          end
    events[key]
  end

  def do_out_action(states, current_state)
    action = states[current_state][:out_action]
    if action
      self.instance_eval &action
    end
  end

  def do_in_action(states, current_state)
    action = states[current_state][:in_action]
    if action
      self.instance_eval &action
    end
  end

  def stop_active_timer!(timers, timer_name)
    if th = timers[timer_name]
      th.kill
      timers.delete(timer_name)
    end
  end
end


def init_simulator(receiver, proto_klass, ev_receiver, logger)
  @simulator ||= Simulator.new(receiver, proto_klass, ev_receiver, logger)
end

def log(progname, io_target = STDOUT)
  @logger = Logger.new(io_target)
  @logger.progname = progname
  @logger.level = Logger::DEBUG
end

def peer(*args)
  name, own, dst, proto = if args.length == 3
                            [nil, *args]
                          else
                            args
                          end
  own_ip, own_port = own.split(/:/)
  dst_ip, dst_port = dst.split(/:/)

  sock = SignalReceiver.new
  sock.bind(own_ip, own_port.to_i)
  sock.connect(dst_ip, dst_port.to_i)

  @sig_sockets ||= []
  @sig_sockets << [sock, name, proto]
end

def add_sig_sockets
  @sig_sockets.each do |sock_info|
    @simulator.add_peer(* sock_info)
  end
end


def print_states
  ap @simulator
end

def do_event_loop
  @simulator.event_loop
end

def state(state_name, &block)
  @simulator.add_state(state_name, &block)
end

def define(&block)
  @simulator.define(block)
end


#=================================================-
# main
#=================================================-

ev_receiver = EventReceiver.new
ev_receiver.bind('127.0.0.1', 0)
File.open('event.sock', 'w') do |f|
  _, port, _, ip = ev_receiver.addr
  f.puts "#{ip}:#{port}"
end

if ARGV.length == 2
  require_relative ARGV.shift   # load config
else
  require_relative 'config'
end

# initialize simulator
sig_socket = @sig_sockets.shift
init_simulator(
  sig_socket[0],
  sig_socket[2],
  ev_receiver,
  @logger
)

add_sig_sockets


# load scenario file
unless ARGV.empty?
  ARGV.each do |scenario_file|
    require_relative scenario_file
  end
else
    require_relative 'scenario'
end

# execute
do_event_loop

