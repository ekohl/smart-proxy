require 'resolv'
require 'ipaddr'
require 'dns_common/dns_resolver.rb'

module Proxy::Dns
  class Error < RuntimeError; end
  class NotFound < RuntimeError; end
  class Collision < RuntimeError; end

  class Record
    include ::Proxy::Log
    include ::Proxy::Dns::Resolver

    attr_reader :server, :ttl

    def initialize(server = nil, ttl = nil)
      @server = server || "localhost"
      @ttl    = ttl || "86400"
    end

    def resolver
      Resolv::DNS.new(:nameserver => @server)
    end

    def create_a_record(fqdn, ip)
      case a_record_conflicts(fqdn, ip) #returns -1, 0, 1
        when 1 then
          raise(Proxy::Dns::Collision, "'#{fqdn} 'is already in use")
        when 0 then
          return nil
        else
          do_create(fqdn, ip, "A")
      end
    end

    def create_aaaa_record(fqdn, ip)
      case aaaa_record_conflicts(fqdn, ip) #returns -1, 0, 1
        when 1 then
          raise(Proxy::Dns::Collision, "'#{fqdn} 'is already in use")
        when 0 then
          return nil
        else
          do_create(fqdn, ip, "AAAA")
      end
    end

    def create_cname_record(fqdn, target)
      case cname_record_conflicts(fqdn, target) #returns -1, 0, 1
        when 1 then
          raise(Proxy::Dns::Collision, "'#{fqdn} 'is already in use")
        when 0 then
          return nil
        else
          do_create(fqdn, target, "CNAME")
      end
    end

    def create_ptr_record(fqdn, ptr)
      case ptr_record_conflicts(fqdn, ptr) #returns -1, 0, 1
        when 1 then
          raise(Proxy::Dns::Collision, "'#{ptr}' is already in use")
        when 0
          return nil
        else
          do_create(ptr, fqdn, "PTR")
      end
    end

    def do_create(name, value, type)
      raise(Proxy::Dns::Error, "Creation of #{type} not implemented")
    end

    def remove_a_record(fqdn)
      do_remove(fqdn, "A")
    end

    def remove_aaaa_record(fqdn)
      do_remove(fqdn, "AAAA")
    end

    def remove_cname_record(fqdn)
      do_remove(fqdn, "CNAME")
    end

    def remove_ptr_record(name)
      do_remove(name, "PTR")
    end

    def do_remove(name, type)
      raise(Proxy::Dns::Error, "Deletion of #{type} not implemented")
    end

    # conflict methods return values:
    # no conflict: -1; conflict: 1, conflict but record / ip matches: 0
    def a_record_conflicts(fqdn, ip)
      record_conflicts_ip(fqdn, Resolv::DNS::Resource::IN::A, ip)
    end

    def aaaa_record_conflicts(fqdn, ip)
      record_conflicts_ip(fqdn, Resolv::DNS::Resource::IN::AAAA, ip)
    end

    def cname_record_conflicts(fqdn, target)
      record_conflicts_name(fqdn, Resolv::DNS::Resource::IN::CNAME, target)
    end

    def ptr_record_conflicts(content, name)
      if name.match(Resolv::IPv4::Regex) || name.match(Resolv::IPv6::Regex)
        logger.warn(%q{Proxy::Dns::Record#ptr_record_conflicts with a non-ptr record parameter has been deprecated and will be removed in future versions of Smart-Proxy.
                      Please use ::Proxy::Dns::Record#ptr_record_conflicts('101.212.58.216.in-addr.arpa') format instead.})
        name = IPAddr.new(name).reverse
      end
      record_conflicts_name(name, Resolv::DNS::Resource::IN::PTR, content)
    end

    def to_ipaddress ip
      IPAddr.new(ip) rescue false
    end

    private

    def record_conflicts_ip(fqdn, type, ip)
      begin
        ip_addr = IPAddr.new(ip)
      rescue
        raise Proxy::Dns::Error.new("Not an IP Address: '#{ip}'")
      end

      resources = resolver.getresources(fqdn, type)
      return -1 if resources.empty?
      return 0 if resources.any? {|r| IPAddr.new(r.address.to_s) == ip_addr }
      1
    end

    def record_conflicts_name(fqdn, type, content)
      resources = resolver.getresources(fqdn, type)
      return -1 if resources.empty?
      return 0 if resources.any? {|r| r.name.to_s.casecmp(content) == 0 }
      1
    end
  end
end
