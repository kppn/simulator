
state :initial do
  in_action {
    require_relative '/home/ta_kondoh/work/simulator/signal/lora'

    @appkey = ["01010101010101010101010101010101"].pack('H*')
    @decode_params = [{appkey: @appkey}]

    @unconfirmed_data_up.macpayload.fhdr.fctrl.adr = true

    @fcnt = 0

    transit :join
  }
end


state :join do
  in_action {
    @join_request.macpayload.devnonce = [Random.rand(65535)].pack('n')
    send @join_request.encode(appkey: @appkey)
    start_timer :wait_join_accept, 10
  }

  expire( :wait_join_accept ) {
    transit :join
  }

  receive(->{ @sig.mhdr.join_accept? }) {
    @nwkskey, @appskey = KeyGenerator.new(@join_request, @sig, @appkey).get_keys
    @decode_params = [{appkey: @appkey, nwkskey: @nwkskey, appskey: @appskey}]

    @unconfirmed_data_up.macpayload.fhdr.devaddr = @sig.macpayload.devaddr
    
    transit :send_payload
  }
end


state :send_payload do
  in_action {
    start_timer :send_uplink, 5
  }

  expire( :send_uplink ) {
    @unconfirmed_data_up.macpayload.fhdr.fcnt = (@fcnt += 1)

    send @unconfirmed_data_up.encode(*@decode_params)

    start_timer :send_uplink, 5
  }
  
  receive(->{ @sig.mhdr.confirmed_data_down? }) {
    #@uplink_payload_empty.macpayload.fcnt = (@fcnt += 1)
    #@uplink_payload_empty.mhdr.mtype = MHDR::ConfirmedDataUp

    #send @uplink_payload_empty.encode(*@decode_params)
  }
end

