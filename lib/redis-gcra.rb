require "digest/sha1"
require "thread"

module RedisGCRA
  extend self

  autoload :Result, "redis-gcra/result"

  def limit(redis:, key:, burst:, rate:, period:, cost: 1)
    call(redis, :perform_gcra_ratelimit, key, burst, rate, period, cost)
  end

  def peek(redis:, key:, burst:, rate:, period:)
    call(redis, :inspect_gcra_ratelimit, key, burst, rate, period)
  end

  private

  def call(redis, script_name, key, *argv)
    res = call_script(redis, script_name, keys: [key], argv: argv)

    Result.new(
      limited: res[0] == 1,
      remaining: res[1],
      retry_after: parse_float_string(res[2]),
      reset_after: parse_float_string(res[3])
    )
  end

  def parse_float_string(value)
    value == "-1" ? nil : value.to_f
  end

  def call_script(redis, script_name, *args)
    script_sha = mutex.synchronize { get_cached_sha(redis, script_name) }
    redis.evalsha(script_sha, *args)
  end

  def redis_cache
    @redis_script_cache ||= {}
  end

  def mutex
    @mutex ||= Mutex.new
  end

  def get_cached_sha(redis, script_name)
    cache_key = "#{redis.id}/#{script_name}"
    redis_cache[cache_key] ||= load_script(redis, script_name)
  end

  def load_script(redis, script_name)
    script_path = File.expand_path("../../vendor/#{script_name}.lua", __FILE__)
    script = File.read(script_path)
    script_sha = Digest::SHA1.hexdigest(script)
    return script_sha if redis.script(:exists, script_sha)
    redis.script(:load, script)
  end
end
