module Proxy::PuppetCa
  class Plugin < ::Proxy::Plugin
    rackup_path File.expand_path("http_config.ru", __dir__)

    uses_provider
    default_settings :use_provider => 'puppetca_hostname_whitelisting',
      :puppet_ssl_ca => '/etc/puppetlabs/puppet/ssl/certs/ca.pem'

    validate :puppet_url, :url => true
    expose_setting :puppet_url
    validate_readable :puppet_ssl_ca, :puppet_ssl_cert, :puppet_ssl_key

    load_classes ::Proxy::PuppetCa::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::PuppetCa::PluginConfiguration

    plugin :puppetca, ::Proxy::VERSION
  end
end
