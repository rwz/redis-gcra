require "thread"

module RedisGCRA
  extend self

  autoload :Result, "redis-gcra/result"

  def limit(redis:, key:, burst:, rate:, period:, cost: 1)
    resp = call_script(
      redis,
      :perform_gcra_ratelimit,
      keys: [key],
      argv: [burst, rate, period, cost]
    )

    Result.new(
      limited: resp[0] == 1,
      remaining: resp[1],
      retry_after: resp[2] == "-1" ? nil : resp[2].to_f,
      reset_after: resp[3].to_f
    )
  end

  private

  def call_script(redis, script_name, *args)
    script_sha = mutex.synchronize { get_cached_sha(redis, script_name) }
    redis.evalsha script_sha, *args
  end

  def redis_cache
    @redis_script_cache ||= {}
  end

  def mutex
    @mutex ||= Mutex.new
  end

  def get_cached_sha(redis, script_name)
    sha = redis_cache.dig(redis.id, script_name)
    return sha if sha

    script = File.read(File.expand_path("../../vendor/#{script_name}.lua", __FILE__))
    sha = redis.script(:load, script)
    redis_cache[redis.id] ||= {}
    redis_cache[redis.id][script_name] = sha
    sha
  end
end
