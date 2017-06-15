@simulator.instance_eval do

gw_eui = ['DEADBEAFDEADBEAF'].pack('H*')

@stat = PacketForwarder.new(
  head: PacketForwarder::Head.new(
    protocol_version: 1,
    identifier: PacketForwarder::Head::PushData,
  ),
  guid: gw_eui,
  payload: {
    'stat' => {
      'time' => nil,    # Time.now.strftime("%F %T %Z")
      'lati' => 35.2442,
      'long' => 139.6794,
      'alti' => 0,
      'rxnb' => nil,    # rxnb
      'rxok' => nil,    # rxok
      'rxfw' => nil,    # rxfw
      'ackr' => 100.0,
      'dwnb' => nil,    # rxnb
      'txnb' => 0,
    }
  }
)


@push_data = PacketForwarder.new(
  head: PacketForwarder::Head.new(
    protocol_version: 1,
    identifier: PacketForwarder::Head::PushData,
  ),
  guid: gw_eui,
  payload: {
    'rxpk' => [
      {
        'time' => nil,   # Time.now.strftime("%FT%T.%L000Z"),
        'tmst' => nil,   # Time.now.to_i,
        'freq' => 923.2,
        'chan' => 2,
        'rfch' => 0,
        'stat' => 1,
        'modu' => "LORA",
        'datr' => "SF7BW125",
        'codr' => "4/5",
        'rssi' => -40,
        'lsnr' => 2.0,
        'size' => nil,  # data.length,
        'data' => nil,  # Base64.encode64(data)
      }
    ]
  }
)

@pull_data = PacketForwarder.new(
  head: PacketForwarder::Head.new(
    protocol_version: 1,
    identifier: PacketForwarder::Head::PullData,
  ),
  guid: gw_eui,
  payload: nil
)

@tx_ack = PacketForwarder.new(
  head: PacketForwarder::Head.new(
    protocol_version: 1,
    identifier: PacketForwarder::Head::TxAck,
  ),
  guid: gw_eui,
  payload: nil
)

end
