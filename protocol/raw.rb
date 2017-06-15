class Raw
  attr_accessor :value

  def self.from_bytes(byte_str)
    raw = self.new
    raw.value = byte_str
    raw
  end

  def encode
    self.value
  end
end

