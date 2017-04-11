require "spec_helper"

describe RedisGCRA do
  let(:redis) { RedisConnection }

  context "#limit" do
    def call(key: "foo", cost: 1, burst: 300, rate: 60, period: 60)
      described_class.limit(
        redis: redis,
        key: key,
        burst: burst,
        rate: rate,
        period: period,
        cost: cost
      )
    end

    it "calculates rate limit result" do
      100.times { call }
      result = call
      expect(result).to_not be_limited
      expect(result.remaining).to eq(199)
      expect(result.retry_after).to be_nil
      expect(result.reset_after).to be_within(0.1).of(101.0)
    end

    it "rate limits different keys independently" do
      100.times { call cost: 10 }
      result = call(cost: 2, key: "bar")
      expect(result).to_not be_limited
      expect(result.remaining).to eq(298)
      expect(result.retry_after).to be_nil
      expect(result.reset_after).to be_within(0.1).of(2.0)
    end

    it "calculates rate limit with non-1 cost correctly" do
      100.times { call(cost: 2) }
      result = call(cost: 2)
      expect(result).to_not be_limited
      expect(result.remaining).to eq(98)
      expect(result.retry_after).to be_nil
      expect(result.reset_after).to be_within(0.1).of(202.0)
    end

    it "limits once bucket has been depleted" do
      300.times { call }

      10.times do
        result = call
        expect(result).to be_limited
        expect(result.remaining).to be(0)
        expect(result.retry_after).to be_within(0.5).of(1.0)
        expect(result.reset_after).to be_within(0.5).of(300.0)
      end
    end

    it "recovers after certain time" do
      300.times { call }
      limited_result = call
      expect(limited_result).to be_limited
      sleep limited_result.retry_after
      passed_result = call
      expect(passed_result).to_not be_limited
    end

    it "should pass when cost is bigger than the remaining" do
      call cost: 299
      result = call(cost: 2)
      expect(result).to be_limited
      expect(result.remaining).to eq(0)
      expect(result.retry_after).to be_within(0.1).of(1.0)
    end

    test_cases = [
      { burst: 1000, rate: 100, period: 60, cost: 2,    repeat: 1, expected_remaining: 998 },
      { burst: 1000, rate: 100, period: 60, cost: 200,  repeat: 1, expected_remaining: 800 },
      { burst: 1000, rate: 100, period: 60, cost: 200,  repeat: 4, expected_remaining: 200 },
      { burst: 1000, rate: 100, period: 60, cost: 200,  repeat: 5, expected_remaining: 0 },
      { burst: 1000, rate: 100, period: 60, cost: 1,    repeat: 137, expected_remaining: 863 },
      { burst: 1000, rate: 100, period: 60, cost: 1001, repeat: 1, expected_remaining: 0 }
    ]

    test_cases.each_with_index do |test_case, index|
      it "calculates test case ##{index+1} correctly" do
        result = test_case[:repeat].times.map do
          call(
            burst: test_case[:burst],
            rate: test_case[:burst],
            period: test_case[:period],
            cost: test_case[:cost]
          )
        end.last

        expect(result.remaining).to eq(test_case[:expected_remaining])
      end
    end
  end

  context "#peek" do
    let(:default_config) { { redis: redis, key: "foo", burst: 300, rate: 60, period: 60 } }

    def peek(**options)
      described_class.peek(**default_config.merge(options))
    end

    def limit(cost: 1, **options)
      described_class.limit(cost: cost, **default_config.merge(options))
    end

    it "returns initial state without modifying it" do
      result = peek

      expect(result).to_not be_limited
      expect(result.remaining).to eq(300)
      expect(result.retry_after).to be_nil
      expect(result.reset_after).to be_nil
    end

    it "describeds partially drained state correctly" do
      limit cost: 10

      result = peek

      expect(result).to_not be_limited
      expect(result.remaining).to eq(290)
      expect(result.retry_after).to be_nil
      expect(result.reset_after).to be_within(0.1).of(10.0)
    end

    it "describes fully drained state correctly" do
      limit cost: 300

      sleep 0.5

      result = peek

      expect(result).to be_limited
      expect(result.remaining).to eq(0)
      expect(result.retry_after).to be_within(0.1).of(0.5)
      expect(result.reset_after).to be_within(0.1).of(299.5)
    end
  end

  context "caching" do
    it "caches scripts" do
      described_class.instance_eval { redis_cache.clear }
      redis.script :flush

      options = { redis: redis, key: "foo", burst: 300, rate: 60, period: 60 }

      expect { described_class.limit **options }.to_not raise_error
      expect { described_class.peek  **options }.to_not raise_error

      shas = described_class.instance_eval { redis_cache.values }

      shas.each do |sha|
        expect(redis.script(:exists, sha)).to be(true)
      end
    end
  end
end
