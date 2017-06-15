state :initial do
  in_action {
    require_relative '/home/ta_kondoh/work/simulator/signal/pf'

    @t_stat = 30
    @t_pull = 10

    @n_uplink = 0
    @n_downlink = 0

    transit :main
  }
end


state :main do
  in_action {
    start_timer :stat, @t_stat
    start_timer :pull, @t_pull
  }

  expire( :stat ) {
    @stat.head.random_token = Random.rand(0xffff)
    @stat.payload['stat']['time'] = Time.now.strftime("%F %T %Z")
    @stat.payload['stat']['rxnb'] = @n_uplink
    @stat.payload['stat']['rxok'] = @n_uplink
    @stat.payload['stat']['rxfw'] = @n_uplink
    @stat.payload['stat']['dwnb'] = @n_downlink

    send @stat.encode

    start_timer :stat, @t_stat
  }


  # push
  receive(->{true}, :lorasim) {
    @push_data.head.random_token = Random.rand(0xffff)
    p @push_data.payload
    @push_data.payload['rxpk'][0]['time'] = Time.now.strftime("%FT%T.%L000Z")
    @push_data.payload['rxpk'][0]['tmst'] = Time.now.to_i
    @push_data.payload['rxpk'][0]['data'] = @sig.value.encode64
    @push_data.payload['rxpk'][0]['size'] = @sig.value.length

    send @push_data.encode

    @n_uplink += 1
  }

  receive(->{ @sig.head.push_ack? }) {
  }


  # pull
  expire( :pull ) {
    @pull_data.head.random_token = Random.rand(0xffff)

    send @pull_data.encode

    start_timer :pull, @t_pull
  }

  receive(->{ @sig.head.pull_ack? }) {
    @logger.info "receive pull ack."
  }

  receive(->{ @sig.head.pull_resp? }) {
    @n_downlink += 1

    @tx_ack.head.random_token = @sig.head.random_token

    send @tx_ack.encode

    p @sig.payload
    data = @sig.payload['txpk']['data'].decode64
    p 'hoge'
    p data.to_hexstr
    send :lorasim, data
  }
end

