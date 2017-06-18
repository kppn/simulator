
# transit state by timer, each initial - main 
state :initial do
  in_action {
    start_timer :to_main, 3
    stop_timer :to_main
  }

  # never fire this
  expire(:to_main) {
    puts 'timer expired'
  }
end

