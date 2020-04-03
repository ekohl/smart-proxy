module ::Proxy::Puppet
  class ConfigurationLoader
    def load_programmable_settings(settings)
      use_provider = settings[:use_provider]
      use_provider = [use_provider].compact unless use_provider.is_a?(Array)
      settings[:use_provider] = use_provider
      settings[:classes_retriever] = :apiv3
      settings[:environments_retriever] = :apiv3

      settings
    end

    def load_classes
      require 'puppet_proxy_common/errors'
      require 'puppet_proxy/dependency_injection'
      require 'puppet_proxy/puppet_api'
      require 'puppet_proxy_common/environment'
      require 'puppet_proxy_common/puppet_class'
      require 'puppet_proxy_common/api_request'
      require 'puppet_proxy/apiv3'
      require 'puppet_proxy/v3_environments_retriever'
      require 'puppet_proxy/v3_environment_classes_api_classes_retriever'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :environment_retriever_impl,
                                    (lambda do
                                       ::Proxy::Puppet::V3EnvironmentsRetriever.new(
                                         settings[:puppet_url],
                                         settings[:puppet_ssl_ca],
                                         settings[:puppet_ssl_cert],
                                         settings[:puppet_ssl_key])
                                     end)

      container_instance.singleton_dependency :class_retriever_impl,
                                              (lambda do
                                                 ::Proxy::Puppet::V3EnvironmentClassesApiClassesRetriever.new(
                                                   settings[:puppet_url],
                                                   settings[:puppet_ssl_ca],
                                                   settings[:puppet_ssl_cert],
                                                   settings[:puppet_ssl_key],
                                                   settings[:api_timeout])
                                               end)
      container_instance.dependency :class_cache_initializer,
                                    (lambda do
                                       Proxy::Puppet::EnvironmentClassesCacheInitializer.new(
                                         container_instance.get_dependency(:class_retriever_impl),
                                         container_instance.get_dependency(:environment_retriever_impl))
                                     end)
    end
  end
end
