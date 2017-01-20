module Proxy::Dns
  class Resolver
    def get_name(a_ptr)
      get_resource_as_string(a_ptr, Resolv::DNS::Resource::IN::PTR, :name)
    end

    def get_name!(a_ptr)
      get_resource_as_string!(a_ptr, Resolv::DNS::Resource::IN::PTR, :name)
    end

    def get_ipv4_address!(fqdn)
      get_resource_as_string!(fqdn, Resolv::DNS::Resource::IN::A, :address)
    end

    def get_ipv4_address(fqdn)
      get_resource_as_string(fqdn, Resolv::DNS::Resource::IN::A, :address)
    end

    def get_ipv6_address!(fqdn)
      get_resource_as_string!(fqdn, Resolv::DNS::Resource::IN::AAAA, :address)
    end

    def get_ipv6_address(fqdn)
      get_resource_as_string(fqdn, Resolv::DNS::Resource::IN::AAAA, :address)
    end

    def get_resource_as_string(value, resource_type, attr)
      resolver.getresource(value, resource_type).send(attr).to_s
    rescue Resolv::ResolvError
      false
    end

    def get_resource_as_string!(value, resource_type, attr)
      resolver.getresource(value, resource_type).send(attr).to_s
    rescue Resolv::ResolvError
      raise Proxy::Dns::NotFound.new("Cannot find DNS entry for #{value}")
    end

    def ptr_to_ip ptr
     if ptr =~ /\.in-addr\.arpa$/
       ptr.split('.')[0..-3].reverse.join('.')
     elsif ptr =~ /\.ip6\.arpa$/
       ptr.split('.')[0..-3].reverse.each_slice(4).inject([]) {|address, word| address << word.join}.join(":")
     else
       raise Proxy::Dns::Error.new("Not a PTR address: '#{ptr}'")
     end
    end
  end
end
