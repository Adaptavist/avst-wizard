# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "avst-wizard"
  spec.version       = '0.0.43'
  spec.authors       = ["Martin Brehovsky"]
  spec.email         = ["mbrehovsky@adaptavist.com"]
  spec.summary       = %q{Avstwizard}
  spec.description   = %q{Avstwizard}
  spec.homepage      = "http://www.adaptavist.com"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files`.split($\)
  spec.executables   = ["avst-wizard"]
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 1.6"
  spec.add_development_dependency "rake"

  spec.add_dependency "docopt", ">= 0.5.0"
  spec.add_dependency "hiera_loader", ">= 0.0.2"
  spec.add_dependency "hiera-eyaml"
  spec.add_dependency "rainbow"
  spec.add_dependency "nokogiri", ">= 1.8.5"
end

