module Proxy::Puppet
  class Plugin < Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    plugin :puppet, ::Proxy::VERSION

    uses_provider
    load_programmable_settings ::Proxy::Puppet::ConfigurationLoader
    load_classes ::Proxy::Puppet::ConfigurationLoader
    load_dependency_injection_wirings ::Proxy::Puppet::ConfigurationLoader

    default_settings :puppet_ssl_ca => '/etc/puppetlabs/puppet/ssl/certs/ca.pem', :api_timeout => 30
    validate :puppet_url, :url => true
    expose_setting :puppet_url
    validate_readable :puppet_ssl_ca, :puppet_ssl_cert, :puppet_ssl_key

    start_services :class_cache_initializer
  end
end
