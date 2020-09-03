require 'test_helper'
require 'puppet_proxy_common/api_request'
require 'puppet_proxy/errors'
require 'puppet_proxy/apiv3'
require 'puppet_proxy/puppet_class'
require 'puppet_proxy/v3_environment_classes_api_classes_retriever'


class Puppetv3EnvironmentClassesApiRetrieverTest < Test::Unit::TestCase
  def setup
    @retriever = Proxy::Puppet::V3EnvironmentClassesApiClassesRetriever.new(nil, nil, nil, nil, nil, api)
  end

  def api
    Proxy::Puppet::Apiv3
  end

  def test_uses_puppet_environment_classes_api
    api.any_instance.expects(:list_classes).
      with('test_environment', nil, 300).
      returns('files' => [])
    @retriever.get_classes('test_environment')
  end

  def test_passes_cached_etag_value_to_puppetapi
    etag_value = 42
    api.any_instance.expects(:list_classes).
      with('test_environment', etag_value, 300).
      returns([{'files' => []}, etag_value + 1])
    @retriever.instance_variable_get(:@etag_cache)['test_environment'] = etag_value
    @retriever.get_classes('test_environment')
  end

  def test_returns_cached_classes_if_puppet_responds_with_not_modified
    api.any_instance.expects(:list_classes).returns([Proxy::Puppet::Apiv3::NOT_MODIFIED, 42])
    expected_classes =<<~EOL
      {
        "files": [
          {
            "classes": [{"name": "dns::config", "params": []}],
            "path": "/etc/puppetlabs/code/environments/home/modules/dns/manifests/config.pp"
          }],
        "name": "test_environment"
      }
    EOL
    @retriever.instance_variable_get(:@classes_cache)['test_environment'] = JSON.parse(expected_classes)
    assert_equal JSON.parse(expected_classes), @retriever.get_classes('test_environment')
  end

  def test_reuses_future_for_concurrent_environment_classes_retrievals
    fake_future = Object.new
    @retriever.instance_variable_get(:@futures_cache)['test_environment'] = fake_future
    assert_equal fake_future, @retriever.async_get_classes('test_environment')
  end

  def test_clears_futures_cache
    api.any_instance.expects(:list_classes).returns([{'files' => []}, 42])
    @retriever.get_classes('test_environment')
    assert_nil @retriever.instance_variable_get(:@futures_cache)['test_environment']
  end

  def test_clears_futures_cache_if_puppet_responds_with_not_modified
    api.any_instance.expects(:list_classes).returns([Proxy::Puppet::Apiv3::NOT_MODIFIED, 42])
    @retriever.get_classes('test_environment')
    assert_nil @retriever.instance_variable_get(:@futures_cache)['test_environment']
  end

  def test_clears_futures_cache_if_call_to_puppet_raises_an_exception
    api.any_instance.expects(:list_classes).raises(StandardError)
    assert @retriever.async_get_classes('test_environment').wait(1).rejected?
    assert_nil @retriever.instance_variable_get(:@futures_cache)['test_environment']
  end

  def test_raises_timeouterror_if_puppet_takes_too_long_to_respond
    fake_future = Object.new
    fake_future.expects(:value!).returns(nil)
    fake_future.expects(:pending?).returns(true)

    @retriever.stubs(:async_get_classes).returns(fake_future)

    assert_raises(::Proxy::Puppet::TimeoutError) { @retriever.get_classes('test_environment') }
  end

  ENVIRONMENT_CLASSES_RESPONSE = <<~EOL
    {
      "files": [
        {
          "classes": [{"name": "dns::config", "params": []}],
          "path": "/manifests/config.pp"
        },
        {
          "classes": [{"name": "dns::install", "params": []}],
          "path": "/manifests/install.pp"
        },
        {
          "error": "Syntax error at '=>' at /manifests/witherror.pp:20:19",
          "path": "/manifests/witherror.pp"
        }],
      "name": "test_environment"
    }
  EOL
  def test_legacy_parser_with_environment_classes_response
    expected_classes = [Proxy::Puppet::PuppetClass.new("dns::config", {}), Proxy::Puppet::PuppetClass.new("dns::install", {})]
    api.any_instance.expects(:list_classes).returns([JSON.load(ENVIRONMENT_CLASSES_RESPONSE), 42])
    assert_equal expected_classes, @retriever.classes_in_environment('test_environment')
  end

  def test_parser_with_environment_classes_response
    expected_reponse = [
      {"classes" => [{"name" => "dns::config", "params" => []}], "path" => "/manifests/config.pp"},
      { "classes" => [{"name" => "dns::install", "params" => []}], "path" => "/manifests/install.pp"},
      {"error" => "Syntax error at '=>' at /manifests/witherror.pp:20:19", "path" => "/manifests/witherror.pp"},
    ]
    api.any_instance.expects(:list_classes).returns([JSON.load(ENVIRONMENT_CLASSES_RESPONSE), 42])
    assert_equal expected_reponse, @retriever.classes_and_errors_in_environment('test_environment')
  end

  ENVIRONMENT_CLASSES_RESPONSE_WITH_EXPRESSION_PARAMETERS = <<~EOL
    {
      "files": [{"classes": [{"name": "dns",
                              "params": [
                                          {"default_source": "$::dns::params::namedconf_path", "name": "namedconf_path"},
                                          {"default_source": "$::dns::params::dnsdir", "name": "dnsdir"}
                                        ]}],
                 "path": "/manifests/init.pp"
               }],
      "name": "test_environment"
    }
  EOL
  def test_legacy_parser_with_environment_classes_response_with_variable_expression_parameteres
    expected_classes = [Proxy::Puppet::PuppetClass.new("dns", 'namedconf_path' => '${::dns::params::namedconf_path}', 'dnsdir' => '${::dns::params::dnsdir}')]
    api.any_instance.expects(:list_classes).returns([JSON.load(ENVIRONMENT_CLASSES_RESPONSE_WITH_EXPRESSION_PARAMETERS), 42])
    assert_equal expected_classes, @retriever.classes_in_environment('test_environment')
  end

  def test_parser_with_environment_classes_response_with_variable_expression_parameteres
    expected_response = [{
      "classes" => [{
        "name" => "dns",
        "params" => [
          {"default_source" => "${::dns::params::namedconf_path}", "name" => "namedconf_path"},
          {"default_source" => "${::dns::params::dnsdir}", "name" => "dnsdir"},
        ],
      }],
      "path" => "/manifests/init.pp",
    }]
    api.any_instance.expects(:list_classes).returns([JSON.load(ENVIRONMENT_CLASSES_RESPONSE_WITH_EXPRESSION_PARAMETERS), 42])
    assert_equal expected_response, @retriever.classes_and_errors_in_environment('test_environment')
  end

  ENVIRONMENT_CLASSES_RESPONSE_WITH_DEFAULT_LITERALS = <<~EOL
    {
      "files": [{"classes": [{"name": "testing",
                              "params": [
                                          {"default_literal": "literal default", "default_source": "literal default", "name": "string_with_literal_default", "type": "String"},
                                          {
                                            "default_literal": {
                                              "one": "foo",
                                              "two": "hello"
                                            },
                                           "default_source": "{'one' => 'foo', 'two' => 'hello'}",
                                            "name": "a_hash",
                                            "type": "Hash"
                                          }
                              ]}],
                 "path": "init.pp"
               }],
      "name": "test_environment"
    }
  EOL
  def test_legacy_parser_with_puppet_environment_classes_response_with_default_literals
    expected_classes = [Proxy::Puppet::PuppetClass.new("testing", 'string_with_literal_default' => 'literal default', 'a_hash' => {'one' => 'foo', 'two' => 'hello'})]
    api.any_instance.expects(:list_classes).returns([JSON.load(ENVIRONMENT_CLASSES_RESPONSE_WITH_DEFAULT_LITERALS), 42])
    assert_equal expected_classes, @retriever.classes_in_environment('test_environment')
  end

  def test_parser_with_puppet_environment_classes_response_with_default_literals
    expected_response = [{
      "classes" => [{
        "name" => "testing", "params" => [
          {"default_literal" => "literal default", "default_source" => "literal default", "name" => "string_with_literal_default", "type" => "String"},
          {
            "default_literal" => {"one" => "foo", "two" => "hello"},
            "default_source" => "{'one' => 'foo', 'two' => 'hello'}",
            "name" => "a_hash",
            "type" => "Hash"},
        ]
      }],
      "path" => "init.pp",
    }]

    api.any_instance.expects(:list_classes).returns([JSON.load(ENVIRONMENT_CLASSES_RESPONSE_WITH_DEFAULT_LITERALS), 42])
    assert_equal expected_response, @retriever.classes_and_errors_in_environment('test_environment')
  end
end
