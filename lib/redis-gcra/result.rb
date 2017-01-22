module RedisGCRA
  class Result
    attr_reader :remaining, :reset_after, :retry_after

    def initialize(limited:, remaining:, reset_after:, retry_after:)
      @limited = limited
      @remaining = remaining
      @reset_after = reset_after
      @retry_after = retry_after
    end

    def limited?
      !!@limited
    end
  end
end
