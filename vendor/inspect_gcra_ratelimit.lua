local rate_limit_key = KEYS[1]
local burst = ARGV[1]
local rate = ARGV[2]
local period = ARGV[3]

local emission_interval = period / rate
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

local allow_at = math.max(tat, now) - burst_offset
local diff = now - allow_at

local remaining = math.floor(diff / emission_interval)

local reset_after = tat - now
if reset_after == 0 then
  reset_after = -1
end

local limited

if remaining == 0 then
  limited = 1
else
  limited = 0
end

-- retry_after is always nil because it doesn't make much sense in inspect
-- context
local retry_after = -1

return {limited, remaining, tostring(retry_after), tostring(reset_after)}
