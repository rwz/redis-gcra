require "spec_helper"

describe RedisGCRA do
  let(:redis) { RedisConnection }

  context "#limit" do
    def call
      described_class.limit(
        redis: redis,
        key: "foo",
        burst: 300,
        rate: 60,
        period: 60,
        cost: 1
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

    it "caches script" do
      described_class.instance_eval { redis_cache.clear }
      redis.script :flush

      expect(&method(:call)).to_not raise_error

      sha = described_class.instance_eval { redis_cache.values.first.values.first }
      expect(redis.script(:exists, sha)).to be(true)
    end
  end
end
