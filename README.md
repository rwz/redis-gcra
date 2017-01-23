# RedisGCRA
[![Build Status](https://travis-ci.org/rwz/redis-gcra.svg?branch=master)](https://travis-ci.org/rwz/redis-gcra)

This gem is an implementation of [GCRA][gcra] for rate limiting based on Redis.
The code requires Redis version 3.2 or newer since it relies on
[`replicate_commands`][redis-replicate-commands] feature.

[gcra]: https://en.wikipedia.org/wiki/Generic_cell_rate_algorithm
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

In order to perform rate limiting, you need to call the `limit` method.

In this example the rate limit bucket has 1000 tokens in it and recovers at
speed of 100 tokens per minute.

```ruby
redis = Redis.new

result = RedisGCRA.limit(
  redis: redis,
  key: "overall-account/bob@example.com",
  burst: 1000,
  rate: 100,
  period: 60, # seconds
  cost: 2
)

result.limited?    # => false - request should not be limited
result.remaning    # => 998   - remaining number of requests until limited
result.retry_after # => nil   - can retry without delay
result.reset_after # => ~0.6  - in 0.6 seconds rate limiter will completely reset

# call limit 499 more times in rapid succession and you get:

result.limited?    # => true - request should be limited
result.remaining   # => 0    - no requests can be made at this point
result.retry_after # => ~1.1 - can retry in 1.1 seconds
result.reset_after # => ~600 - in 600 seconds rate limiter will completely reset
```

The implementation utilizes single key in Redis that matches the key you pass
to the `limit` method. If you need to reset rate limiter for particular key,
just delete the key from Redis:

```ruby
# Let's imagine `overall-account/bob@example.com` is limited.
# This will effectively reset limit for the key:
redis.del "overall-account/bob@example.com"
```

You call also retrieve the current state of rate limiter for particular key
without actually modifying the state. In order to do that, use the `peek`
method:

```ruby
RedisGCRA.peek(
  redis: redis,
  key: "overall-account/bob@example.com",
  burst: 1000,
  rate: 100,
  period: 60 # seconds
)

result.limited?    # => true - current state is limited
result.remaining   # => 0    - no requests can be made
result.retry_after # => nil  - peek always returns nil here
result.reset_after # => ~600 - in 600 seconds rate limiter will completely reset
```

## Inspiration

This code was inspired by this great [blog post][blog-post] by [Brandur
Leach][brandur] and his amazing work on [throttled Go package][throttled].

[blog-post]: https://brandur.org/rate-limiting
[brandur]: https://github.com/brandur
[throttled]: https://github.com/throttled/throttled

## License

The gem is available as open source under the terms of the [MIT License][mit].

[mit]: http://opensource.org/licenses/MIT

