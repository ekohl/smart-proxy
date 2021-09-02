require 'test_helper'
require 'puppetca/puppetca'

class PuppetCaConfigTest < Test::Unit::TestCase
  def test_omitted_settings_have_default_values
    Proxy::PuppetCa::Plugin.load_test_settings()
    assert_equal '/etc/puppetlabs/puppet/ssl/certs/ca.pem', Proxy::PuppetCa::Plugin.settings.puppet_ssl_ca
  end
end
