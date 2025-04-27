Gem::Specification.new do |spec|
    spec.name          = "twikey_sdk"
    spec.version       = "0.1.0"
    spec.authors       = ["Koen Serry"]
    spec.summary       = "Ruby SDK for Twikey API"
    spec.files         = Dir["lib/**/*.rb"]
    spec.require_paths = ["lib"]
    spec.add_dependency "json"
  end