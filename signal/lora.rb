@simulator.instance_eval do

appeui = ['0102030405060708'].pack('H*')
deveui = ['1112131415161718'].pack('H*')

@join_request = 
  PHYPayload.new(
    mhdr: MHDR.new(
      mtype: MHDR::JoinRequest
    ),
    macpayload: JoinRequestPayload.new(
      appeui: appeui,
      deveui: deveui,
      devnonce: "\x21\x22"
    ),
    mic: '',
  )

@unconfirmed_data_up = 
  PHYPayload.new(
    mhdr: MHDR.new(
      mtype: MHDR::UnconfirmedDataUp
    ),
    macpayload: MACPayload.new(
      fhdr: FHDR.new(
        devaddr: DevAddr.new(
          nwkid:   0b1000000,
          nwkaddr: 0b0_10000001_10000010_10000011
        ),
        fctrl: FCtrl.new(
          adr: false,
          adrackreq: false,
          ack: false
        ),
        fcnt: 0,
        fopts: nil
      ),
      fport: 1,
      frmpayload: FRMPayload.new("\x01\x02\x03\x04\x05\x06\x07\x08")
    ),
  )

end
