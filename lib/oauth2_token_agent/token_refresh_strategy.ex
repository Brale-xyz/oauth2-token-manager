defmodule OAuth2TokenAgent.TokenRefreshStrategy do
  @moduledoc """
  Module defining a struct for representing strategies for refreshing tokens and
  the functions for applying them
  """

  @typedoc """
  Struct for the refresh timing strategy for OAuth2 tokens; multiple mechanisms

  ## Fields
    * `:every_seconds` - refresh the token if at least the specified number of seconds has elapsed since the last refresh
    * `:seconds_before_expires` - refresh the token if it will expire within the specified number of seconds
  """

  use TypedStruct

  alias __MODULE__

  typedstruct do
    field(:every_seconds, integer())
    field(:seconds_before_expires, integer())
  end

  @doc """
  Returns true if at least one of the conditions is met and the token should be refreshed
  """
  @spec refresh_now?(TokenRefreshStrategy.t(), Calendar.datetime(), Calendar.datetime()) ::
          boolean()
  def refresh_now?(strategy, lastRefreshed, expiresAt) do
    (strategy.every_seconds &&
       strategy.every_seconds <= DateTime.diff(DateTime.utc_now(), lastRefreshed)) ||
      (strategy.seconds_before_expires && expiresAt &&
         strategy.seconds_before_expires >= DateTime.diff(expiresAt, DateTime.utc_now()))
  end
end
