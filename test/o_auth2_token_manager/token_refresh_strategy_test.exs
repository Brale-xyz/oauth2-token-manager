defmodule OAuth2TokenManager.TokenRefreshStrategyTest do
  @moduledoc """
  Tests the refresh strategies configured with TokenRefreshStrategy
  """

  use ExUnit.Case

  alias OAuth2TokenManager.TokenRefreshStrategy

  defp seconds_from_now(seconds) do
    DateTime.utc_now() |> DateTime.add(seconds, :second, Calendar.UTCOnlyTimeZoneDatabase)
  end

  describe "every_seconds" do
    test "refresh_now? is true if it has been more than the configured value of seconds since the last refresh" do
      strategy = %TokenRefreshStrategy{
        every_seconds: 30
      }

      assert !TokenRefreshStrategy.refresh_now?(
               strategy,
               DateTime.utc_now(),
               seconds_from_now(300)
             )

      assert TokenRefreshStrategy.refresh_now?(
               strategy,
               seconds_from_now(-30),
               seconds_from_now(300)
             )
    end
  end

  describe "seconds_before_expires" do
    test "refresh_now? is true if if the token expires at or before the specified number of seconds" do
      strategy = %TokenRefreshStrategy{
        seconds_before_expires: 30
      }

      assert !TokenRefreshStrategy.refresh_now?(
               strategy,
               seconds_from_now(-30),
               seconds_from_now(60)
             )

      assert TokenRefreshStrategy.refresh_now?(
               strategy,
               seconds_from_now(-30),
               seconds_from_now(30)
             )
    end

    test "refresh_now is false if expires_at is nil" do
      strategy = %TokenRefreshStrategy{
        seconds_before_expires: 30
      }

      assert !TokenRefreshStrategy.refresh_now?(
               strategy,
               seconds_from_now(-30),
               nil
             )
    end
  end

  describe "refresh_now?" do
    test "returns true if any of the conditions in the strategy are met" do
      strategy = %TokenRefreshStrategy{
        seconds_before_expires: 30,
        every_seconds: 60
      }

      assert !TokenRefreshStrategy.refresh_now?(
               strategy,
               seconds_from_now(-30),
               seconds_from_now(60)
             )

      assert TokenRefreshStrategy.refresh_now?(
               strategy,
               seconds_from_now(-60),
               seconds_from_now(30)
             )

      assert TokenRefreshStrategy.refresh_now?(
               strategy,
               seconds_from_now(-30),
               seconds_from_now(30)
             )

      assert TokenRefreshStrategy.refresh_now?(
               strategy,
               seconds_from_now(-60),
               seconds_from_now(60)
             )
    end

    test "returns false if none of the conditions in the strategy are specified" do
      strategy = %TokenRefreshStrategy{}

      assert !TokenRefreshStrategy.refresh_now?(
               strategy,
               seconds_from_now(-1),
               seconds_from_now(1)
             )
    end
  end
end
