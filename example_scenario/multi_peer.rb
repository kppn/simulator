
state :initial do
  in_action {
    transit :bridge
  }
end

state :bridge do
  receive(->{ true }) {
    send :other, @sig.encode
  }

  receive(->{ true }, :other) {
    send @sig.encode
  }
end

