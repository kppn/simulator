
# transit state by timer, each initial - main 
state :initial do
  in_action {
    start_timer :to_main, 3
  }

  expire(:to_main) {
    transit :main
  }
end

state :main do
  in_action {
    start_timer :to_initial, 2
  }

  expire(:to_initial) {
    transit :initial
  }
end

