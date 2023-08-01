group :test do
  gem 'mocha', '~> 1.10', :require => false
  gem 'ci_reporter', '>= 1.6.3', "< 2.0.0", :require => false
  gem 'test-unit'
  gem 'benchmark-ips'
  gem 'ruby-prof', '< 1.4'
  gem 'rack-test'
  gem 'rake'
  gem 'webmock'

  # RuboCop
  gem 'rubocop', '~> 1.55.0'
  gem 'rubocop-rake', '~> 0.6.0'
  gem 'rubocop-performance', '~> 1.18'

  # Technically this is a hard dependency of the facts module but that's only
  # used in discovery. This at least allows us to run the tests on it
  gem 'facter', :require => false
end
