require File.expand_path("../lib/redis-gcra/version", __FILE__)

Gem::Specification.new do |spec|
  spec.name         = "redis-gcra"
  spec.version      = RedisGCRA::VERSION
  spec.authors      = ["Pavel Pravosud"]
  spec.email        = ["pavel@pravosud.com"]
  spec.summary      = "Rate limiting based on Generic Cell Rate Algorithm"
  spec.homepage     = "https://github.com/rwz/redis-gcra"
  spec.license      = "MIT"
  spec.files        = Dir["LICENSE.txt", "README.md", "lib/**/**", "vendor/**/**"]
  spec.require_path = "lib"

  spec.add_dependency "redis", ">= 3.3", "< 5"
end
