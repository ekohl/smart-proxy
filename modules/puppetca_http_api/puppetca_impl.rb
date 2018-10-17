module ::Proxy::PuppetCa::PuppetcaHttpApi
  class PuppetcaImpl
    extend Proxy::PuppetCa::DependencyInjection
    inject_attr :http_api_impl, :client

    def sign(certname)
      client.sign(certname)
    end

    def clean(certname)
      client.clean(certname)
    end

    # list of all certificates and their state/fingerprint
    def list
      response = client.search
      response.each_with_object({}) do |entry, hsh|
        name = entry['name']
        # serial, not_before and not_after are not available via http api
        # see https://tickets.puppetlabs.com/browse/SERVER-2370
        hsh[name] = {
          'state' => entry['state'],
          'fingerprint' => entry['fingerprint'],
          'serial' => nil,
          'not_before' => nil,
          'not_after' => nil
        }
      end
    end
  end
end
