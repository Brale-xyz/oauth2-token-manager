defmodule OAuth2TokenManager.TokenAgent do
  @moduledoc """
  Defines the Agent used to manage the token and the struct it uses to store its state
  """

  use Agent
  use TypedStruct

  alias __MODULE__
  alias OAuth2TokenManager.TokenRefreshStrategy
  alias OAuth2.{AccessToken, Client, Error, Response}

  require Logger

  @typedoc """
  Struct for tracking the state of the agent
  """
  typedstruct do
    field(:name, String.t(), enforce: true)
    field(:initial_client, Client.t(), enforce: true)
    field(:client_with_token, Client.t(), enforce: true)
    field(:inline_refresh_strategy, TokenRefreshStrategy.t())
    field(:last_refreshed, Calendar.datetime(), enforce: true)
  end

  @type option ::
          {:name, term()}
          | {:initial_client, Client.t()}
          | {:inline_refresh_strategy, TokenRefreshStrategy.t()}

  @spec start_link([option()]) :: Agent.on_start() | {:error, Response.t()} | {:error, Error.t()}
  def start_link(opts) do
    case Keyword.fetch(opts, :initial_client) do
      :error ->
        {:error, ":initial_client required"}

      {:ok, initial_client} ->
        inline_refresh_strategy =
          Keyword.get(opts, :inline_refresh_strategy, %TokenRefreshStrategy{
            seconds_before_expires: 30,
            every_seconds: 300
          })

        name = Keyword.get(opts, :name)

        case Client.get_token(initial_client) do
          {:ok, client_with_token} ->
            Agent.start_link(
              fn ->
                %TokenAgent{
                  name: name,
                  initial_client: initial_client,
                  client_with_token: client_with_token,
                  inline_refresh_strategy: inline_refresh_strategy,
                  last_refreshed: DateTime.utc_now()
                }
              end,
              name: name
            )

          error ->
            error
        end
    end
  end

  @doc """
  Returns the current client instance; if :inline_updates is configured, the client will be refreshed first if the strategy indicates
  it needs to be
  """
  @spec get_current_client(Agent.agent()) :: Client.t()
  def get_current_client(token_agent) do
    Agent.get_and_update(token_agent, fn state ->
      new_state =
        if state.inline_refresh_strategy &&
             TokenRefreshStrategy.refresh_now?(
               state.inline_refresh_strategy,
               state.last_refreshed,
               DateTime.from_unix!(state.client_with_token.token.expires_at)
             ) do
          get_state_with_new_tokens(state)
        else
          state
        end

      {new_state.client_with_token, new_state}
    end)
  end

  @doc """
  Returns the current access token; if :inline_updates is configured, the token will be refreshed first if the strategy indicates
  it needs to be
  """
  @spec get_access_token(Agent.agent()) :: String.t()
  def get_access_token(token_agent) do
    get_current_client(token_agent).token.access_token
  end

  @doc """
  Triggers a refresh of the agent's tokens
  """
  @spec refresh(Agent.agent()) :: :ok
  def refresh(token_agent) do
    Agent.update(token_agent, fn state ->
      get_state_with_new_tokens(state)
    end)
  end

  defp get_state_with_new_tokens(
         %TokenAgent{client_with_token: %Client{token: nil}, initial_client: client} = state
       ) do
    Logger.info("Refreshing tokens for TokenAgent #{state.name}")

    %TokenAgent{
      state
      | client_with_token: Client.get_token!(client),
        last_refreshed: DateTime.utc_now()
    }
  end

  defp get_state_with_new_tokens(
         %TokenAgent{
           client_with_token: %Client{token: %AccessToken{refresh_token: nil}},
           initial_client: client
         } = state
       ) do
    Logger.info("Refreshing tokens for TokenAgent #{state.name}")

    %TokenAgent{
      state
      | client_with_token: Client.get_token!(client),
        last_refreshed: DateTime.utc_now()
    }
  end

  defp get_state_with_new_tokens(
         %TokenAgent{client_with_token: client_with_token, initial_client: initial_client} =
           state
       ) do
    Logger.info("Refreshing tokens for TokenAgent #{state.name}")

    case Client.refresh_token(client_with_token) do
      {:ok, client} ->
        %TokenAgent{state | client_with_token: client, last_refreshed: DateTime.utc_now()}

      {:error, error} ->
        Logger.warning(
          "Unable to use refresh token for TokenAgent #{state.name}: #{inspect(error)}; attempting to obtain new tokens using the initial client"
        )

        %TokenAgent{
          state
          | client_with_token: Client.get_token!(initial_client),
            last_refreshed: DateTime.utc_now()
        }
    end
  end
end
