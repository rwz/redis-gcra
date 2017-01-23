# RedisGCRA
[![Build Status](https://travis-ci.org/rwz/redis-gcra.svg?branch=master)](https://travis-ci.org/rwz/redis-gcra)

This gem is an implementation of GCRA for rate limiting based on Redis. The
code requires Redis version 3.2 or newer since it relies on
[`replicate_commands`][redis-replicate-commands] feature.

[redis-replicate-commands]: https://redis.io/commands/eval#replicating-commands-instead-of-scripts
## Installation

```ruby
gem "redis-gcra"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redis-gcra

## Usage

```ruby
redis = Redis.new

result = RedisGCRA.limit(
  redis: redis,
  key: "rate-limit-key",
  burst: 1000,
  rate: 100,
  period: 60,
  cost: 2
)

result.limited?    # => false - request should not be limited
result.remaning    # => 998   - remaining number of requests until limited
result.retry_after # => nil   - can retry without delay
result.reset_after # => ~0.6  - in 0.6 seconds rate limiter will completely reset

# do this 500 more times and then

result.limited?    # => true - request should be limited
result.remaining   # => 0    - no requests can be made at this point
result.retry_after # => ~1.1 - can retry in 1.1 seconds
result.reset_after # => ~600 - in 600 seconds rate limiter will completely reset
```

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

