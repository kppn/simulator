
state :initial do
  in_action {
    transit :state1
  }
end

state :state1 do
  receive(->{ @sig.version == 0x61 }) {
    transit :state2
  }
end

state :state2 do
  receive(->{ @sig.version == 0x62 }) {
    transit :state1
  }
end

