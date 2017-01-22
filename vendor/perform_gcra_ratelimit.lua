-- this script has side-effects, so it requires replicate commands mode
redis.replicate_commands()

local rate_limit_key = KEYS[1]
local burst = ARGV[1]
local rate = ARGV[2]
local period = ARGV[3]
local cost = ARGV[4]

local emission_interval = period / rate
local increment = emission_interval * cost
local burst_offset = emission_interval * burst
local now = redis.call("TIME")

-- redis returns time as an array containing two integers: seconds of the epoch
-- time and microseconds. for convenience we need to convert them to float
-- point number
now = now[1] + now[2] / 1000000

local tat = redis.call("GET", rate_limit_key)

if not tat then
  tat = now
else
  tat = tonumber(tat)
end

local new_tat = math.max(tat, now) + increment

local allow_at = new_tat - burst_offset
local diff = now - allow_at

local limited
local remaining
local retry_after
local reset_after

if diff < 0 then
  limited = 1
  remaining = 0
  reset_after = tat - now
  retry_after = diff * -1
else
  local ttl = new_tat - now
  redis.call("SET", rate_limit_key, new_tat, "EX", math.ceil(ttl))
  local next_in = burst_offset - ttl
  remaining = next_in / emission_interval
  reset_after = ttl
  retry_after = -1
  limited = 0
end

return {limited, remaining, tostring(retry_after), tostring(reset_after)}
