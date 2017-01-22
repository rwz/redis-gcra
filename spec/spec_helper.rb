require "redis"
require "redis-gcra"

RedisConnection = Redis.new

RSpec.configure do |config|
  config.before(:example) { RedisConnection.flushall }
end
