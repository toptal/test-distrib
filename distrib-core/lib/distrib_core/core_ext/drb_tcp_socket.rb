module DRb
  # A monkey patch to reduce connection timeout on DRb Socket.
  # The following monkey-patch sets much lower value for connection timeout
  # By default it is over 2 minutes and it is causing a major worker shutdown
  # delay when the leader has finished already.
  #
  # @see https://rubydoc.info/stdlib/drb/DRb
  # @see https://rubydoc.info/stdlib/drb/DRb/DRbTCPSocket
  # @see https://github.com/ruby/drb/blob/master/lib/drb/drb.rb
  class DRbTCPSocket
    # @param uri [String]
    # @param config [Hash]
    def self.open(uri, config)
      host, port, = parse_uri(uri)
      # Original line was:
      # soc = TCPSocket.open(host, port)
      timeout = DistribCore.configuration.drb_tcp_socket_connection_timeout
      soc = Socket.tcp(host, port, connect_timeout: timeout)
      new(uri, soc, config)
    end
  end
end
