require "uri"
require "resolv"
require "ipaddr"

module Translation
  class SafeEndpoint
    class Invalid < StandardError; end
    BLOCKED = %w[
      0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16
      172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.168.0.0/16
      198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4
      240.0.0.0/4 ::/128 ::1/128 fc00::/7 fe80::/10 ff00::/8
      2001:db8::/32
    ].map { |cidr| IPAddr.new(cidr) }.freeze

    def self.parse!(value)
      uri = URI.parse(value.to_s)
      raise Invalid, "HTTPS URL required" unless uri.is_a?(URI::HTTPS)
      raise Invalid, "Invalid hostname" unless uri.host && uri.host.match?(/\A[a-zA-Z0-9][a-zA-Z0-9.\-]*\z/)
      raise Invalid, "Standard HTTPS port 443 required" unless uri.port == 443
      raise Invalid, "Internal hostname is prohibited" if uri.host.match?(/(?:^|\.)(localhost|local|internal|test|invalid)\z/i)
      raise Invalid, "Credentials, query and fragment are prohibited" if uri.userinfo || uri.query || uri.fragment
      raise Invalid, "Base URL must not contain a path" unless uri.path.blank? || uri.path == "/"
      raise Invalid, "URL is too long" if value.to_s.length > 500
      resolve!(uri)
      uri
    rescue URI::InvalidURIError
      raise Invalid, "Malformed URL"
    end

    def self.resolve!(uri)
      addresses = Resolv.getaddresses(uri.host)
      raise Invalid, "Hostname could not be resolved" if addresses.empty?
      addresses.each do |raw|
        ip = IPAddr.new(raw)
        # IPv4-mapped IPv6 may hide a local IPv4 address.
        ip = ip.native if ip.ipv4_mapped?
        raise Invalid, "Endpoint resolves to a disallowed network" if BLOCKED.any? { |range| range.include?(ip) }
        raise Invalid, "Endpoint IP is not globally routable" unless globally_routable?(ip)
      end
      addresses.first
    rescue Resolv::ResolvError, IPAddr::InvalidAddressError
      raise Invalid, "Hostname could not be resolved"
    end

    def self.globally_routable?(ip)
      # Additional hardening can be applied through a deployment-level egress firewall.
      !(ip.link_local? || ip.private?)
    end
  end
end
