module Translation
  module Adapters
    class BaseAdapter
      class UnsupportedProbe < StandardError; end
      def initialize(connection:, base_url: nil)
        @connection = connection
        @client = Translation::HttpClient.new(base_url: base_url || connection.base_url, token: connection.api_token)
      end
      def connection_check = raise(UnsupportedProbe, "No safe non-inference probe supported")
      def submit(**) = raise(NotImplementedError)
      def fetch_status(**) = raise(NotImplementedError)
      def asynchronous? = false
    end
  end
end
