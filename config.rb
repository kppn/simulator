log 'LoRa Simulator'

#require_relative '/home/ta_kondoh/work/device_gw_simulator/lib/lora/protocol.rb'
#require_relative '/home/ta_kondoh/work/device_gw_simulator/lib/packet_forwarder/protocol.rb'

require_relative '/home/ta_kondoh/work/simlator/protocol/raw'

peer '127.0.0.1:50000', '127.0.0.1:50001', Raw
#peer :other, '127.0.0.1:50002', '127.0.0.1:50003', XProto

