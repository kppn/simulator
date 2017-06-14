
state :initial do
  in_action {
    transit :state1
  }
end

state :state1 do
  control(:hoge, 1) {
    transit :state2
  }
end

state :state2 do
  control(:fuga) {
    # do nothing
  }

  control(:foo, 2) {
    transit :state1
  }
end

