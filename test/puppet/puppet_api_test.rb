require 'test_helper'
require 'json'
require 'puppet_proxy/puppet_class'
require 'puppet_proxy/environment'
require 'puppet_proxy/errors'
require 'puppet_proxy/v3_environments_retriever'

class ApiTestEnvironmentsRetriever < ::Proxy::Puppet::V3EnvironmentsRetriever
  def initialize
    @first = ::Proxy::Puppet::Environment.new("first", ["path1", "path2"])
    @second = ::Proxy::Puppet::Environment.new("second", ["path3", "path4"])
  end

  def all
    [@first, @second]
  end
end

class ApiTestClassesRetriever
  def initialize
  end

  def classes_in_environment(an_environment)
    case an_environment
      when 'first'
        [
          ::Proxy::Puppet::PuppetClass.new("dns::install"),
          ::Proxy::Puppet::PuppetClass.new("dns", "dns_server_package" => "${::dns::params::dns_server_package}"),
        ]
      when 'second'
        raise Proxy::Puppet::EnvironmentNotFound.new
      else
        raise "Unexpected environment name '#{an_environment}' was passed in into #classes_in_environment method."
    end
  end

  def classes_and_errors_in_environment(an_environment)
    case an_environment
    when 'first'
      [
        {"classes" => [{"name" => "dns::config", "params" => []}], "path" => "/manifests/config.pp"},
        {"classes" => [{"name" => "dns::install", "params" => []}], "path" => "/manifests/install.pp"},
        {"error" => "Syntax error at '=>' at /manifests/witherror.pp:20:19", "path" => "/manifests/witherror.pp"},
      ]
    else
      raise Proxy::Puppet::EnvironmentNotFound
    end
  end
end

module Proxy::Puppet
  module DependencyInjection
    include Proxy::DependencyInjection::Accessors
    def container_instance
      Proxy::DependencyInjection::Container.new do |c|
        c.dependency :class_retriever_impl, ApiTestClassesRetriever
        c.dependency :environment_retriever_impl, ApiTestEnvironmentsRetriever
      end
    end
  end
end

require 'puppet_proxy/puppet_api'

ENV['RACK_ENV'] = 'test'

class PuppetTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::Puppet::Api.new
  end

  def test_gets_puppet_environments
    get "/environments"
    assert last_response.ok?, "Last response was not ok: #{last_response.body}"
    assert_equal ['first', 'second'], JSON.parse(last_response.body)
  end

  def test_gets_single_puppet_environment
    get '/environments/first'
    assert last_response.ok?, "Last response was not ok: #{last_response.body}"
    data = JSON.parse(last_response.body)
    assert_equal 'first', data["name"]
    assert_equal ['path1', 'path2'], data["paths"]
  end

  def test_missing_single_puppet_environment
    get "/environments/unknown"
    assert_equal 404, last_response.status
  end

  def test_gets_puppet_environment_classes
    get "/environments/first/classes"
    assert last_response.ok?, "Last response was not ok: #{last_response.body}"
    data = JSON.parse(last_response.body)

    assert_equal({'name' => 'install', 'module' => 'dns', 'params' => {}}, data[0]["dns::install"])
    expected_params = { 'dns_server_package' => '${::dns::params::dns_server_package}' }
    assert_equal({'name' => 'dns', 'module' => nil, 'params' => expected_params}, data[1]["dns"])
  end

  def test_gets_environment_classes_and_errors
    get "/environments/first/classes_and_errors"
    assert last_response.ok?, "Last response was not ok: #{last_response.body}"
    data = JSON.parse(last_response.body)

    expected = [
      {"classes" => [{"name" => "dns::config", "params" => []}], "path" => "/manifests/config.pp"},
      {"classes" => [{"name" => "dns::install", "params" => []}], "path" => "/manifests/install.pp"},
      {"error" => "Syntax error at '=>' at /manifests/witherror.pp:20:19", "path" => "/manifests/witherror.pp"},
    ]

    assert_equal expected, data
  end

  def test_get_puppet_class_from_non_existing_environment
    get "/environments/second/classes"
    assert_equal 404, last_response.status
  end

  def test_get_classes_and_errors_from_non_existing_environment
    get "/environments/second/classes_and_errors"
    assert_equal 404, last_response.status
  end

  def test_puppet_run
    post "/run", :nodes => ['node1', 'node2']
    assert_equal 501, last_response.status
  end
end
