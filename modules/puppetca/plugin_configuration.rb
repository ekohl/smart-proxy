module ::Proxy::PuppetCa
  class PluginConfiguration
    def load_classes
      require 'puppetca/dependency_injection'
      require 'puppetca/puppetca_api'
      require 'puppetca/puppetca_impl'
      require 'puppetca/ca_v1_api_request'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :puppetca_impl, -> { ::Proxy::PuppetCa::PuppetcaImpl.new }
      container_instance.dependency :http_api_impl,
                                    lambda {
                                      ::Proxy::PuppetCa::CaApiv1Request.new(
                                        settings[:puppet_url],
                                        settings[:puppet_ssl_ca],
                                        settings[:puppet_ssl_cert],
                                        settings[:puppet_ssl_key]
                                      )
                                    }
    end
  end
end
