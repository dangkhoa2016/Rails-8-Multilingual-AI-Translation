require "net/http"
require "json"
require "openssl"

module Translation
  class HttpClient
    class HttpError < StandardError
      attr_reader :status
      def initialize(status)
        @status = status.to_i
        super("Upstream HTTP #{status}")
      end
    end
    class NetworkError < StandardError; end
    MAX_BODY = 512 * 1024

    def initialize(base_url:, token:)
      @uri = SafeEndpoint.parse!(base_url)
      @token = token
    end

    def get(path, authenticated: true)
      request_json(:get, path, authenticated: authenticated)
    end

    def post(path, data:, idempotency_key: nil)
      request_json(:post, path, data: data, idempotency_key: idempotency_key)
    end

    private

    def request_json(method, path, data: nil, idempotency_key: nil, authenticated: true)
      raise SafeEndpoint::Invalid, "Invalid internal API path" unless path.match?(%r{\A/(?:health|v1/(?:models|jobs/[a-f0-9-]{36}|jobs/translations|chat/completions))\z})
      # Resolve at request time, then pin the TCP connection to that IP (DNS rebinding protection).
      resolved_ip = SafeEndpoint.resolve!(@uri)
      http = Net::HTTP.new(@uri.host, @uri.port, nil)
      http.ipaddr = resolved_ip
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.open_timeout = 5
      http.read_timeout = 20
      http.write_timeout = 10 if http.respond_to?(:write_timeout=)
      http.max_retries = 0 if http.respond_to?(:max_retries=)
      req = method == :get ? Net::HTTP::Get.new(path) : Net::HTTP::Post.new(path)
      req["Accept"] = "application/json"
      req["Authorization"] = "Bearer #{@token}" if authenticated && @token.present?
      req["Idempotency-Key"] = idempotency_key if idempotency_key.present?
      if data
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(data)
      end
      response_body = +""
      response = http.request(req) do |res|
        res.read_body do |chunk|
          response_body << chunk
          raise NetworkError, "Provider response exceeded size limit" if response_body.bytesize > MAX_BODY
        end
      end
      raise HttpError, response.code unless response.code.to_i.between?(200, 299)
      JSON.parse(response_body)
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, SocketError,
           IOError, EOFError, Errno::ECONNRESET, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError => e
      raise NetworkError, e.class.name
    rescue JSON::ParserError
      raise NetworkError, "Malformed JSON response"
    end
  end
end
