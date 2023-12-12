defmodule OAuth2TokenManager.TokenAgentTest do
  @moduledoc """
  Tests for TokenAgent, which is used to track token state
  """
  use ExUnit.Case, async: false

  import Mock

  alias OAuth2.{AccessToken, Client}
  alias OAuth2TokenManager.{TokenAgent, TokenRefreshStrategy}

  defp test_client do
    Client.new(
      strategy: OAuth2.Strategy.ClientCredentials,
      client_id: "test_client_id",
      client_secret: "test_client_secret_abc123",
      site: "http://localhost/"
    )
  end

  describe "start_link/1" do
    test "returns an agent storing the token if successful" do
      with_mock Client, [:passthrough],
        get_token: fn client ->
          {:ok,
           %Client{
             client
             | token: %AccessToken{
                 access_token: "test_access_token",
                 expires_at: (DateTime.utc_now() |> DateTime.to_unix()) + 6000
               }
           }}
        end do
        {:ok, agent} = TokenAgent.start_link(initial_client: test_client())

        assert TokenAgent.get_access_token(agent) == "test_access_token"

        assert TokenAgent.get_current_client(agent).token.access_token == "test_access_token"
      end
    end

    test "returns an error if the initial token retrieval did not succeed" do
      sample_error = %OAuth2.Error{reason: :econnrefused}

      with_mock Client, [:passthrough], get_token: fn _client -> {:error, sample_error} end do
        {:error, error} = TokenAgent.start_link(initial_client: test_client())

        assert error == sample_error
      end
    end

    test "returns an error if no client is provided" do
      {:error, ":initial_client required"} = TokenAgent.start_link(name: MyModule.TokenAgent)
    end

    test "can be provided with an name to refer to the agent" do
      with_mock Client, [:passthrough],
        get_token: fn client ->
          {:ok,
           %Client{
             client
             | token: %AccessToken{
                 access_token: "test_access_token",
                 expires_at: (DateTime.utc_now() |> DateTime.to_unix()) + 6000
               }
           }}
        end do
        {:ok, _} =
          TokenAgent.start_link(
            initial_client: test_client(),
            inline_refresh_strategy: %TokenRefreshStrategy{},
            name: MyModule.TokenAgent
          )

        assert TokenAgent.get_access_token(MyModule.TokenAgent) == "test_access_token"
      end
    end
  end

  describe "refresh_tokens/1" do
    test "uses the refresh token if available" do
      with_mock Client, [:passthrough],
        get_token: fn client ->
          {:ok,
           %Client{
             client
             | token: %AccessToken{
                 access_token: "test_access_token",
                 expires_at: (DateTime.utc_now() |> DateTime.to_unix()) + 600,
                 refresh_token: "test_refresh_token"
               }
           }}
        end,
        refresh_token: fn client ->
          {:ok,
           %Client{
             client
             | token: %AccessToken{
                 access_token: "new_access_token",
                 expires_at: (DateTime.utc_now() |> DateTime.to_unix()) + 600,
                 refresh_token: "new_refresh_token"
               }
           }}
        end do
        {:ok, agent} = TokenAgent.start_link(initial_client: test_client())
        TokenAgent.refresh(agent)

        assert TokenAgent.get_access_token(agent) == "new_access_token"
      end
    end

    test "uses the initial client to get a new token if the refresh token cannot be used" do
      with_mock Client, [:passthrough],
        get_token: fn client ->
          {:ok,
           %Client{
             client
             | token: %AccessToken{
                 access_token: "test_access_token",
                 expires_at: (DateTime.utc_now() |> DateTime.to_unix()) + 600,
                 refresh_token: "test_refresh_token"
               }
           }}
        end,
        refresh_token: fn _client -> {:error, %OAuth2.Error{reason: :econnrefused}} end,
        get_token!: fn client ->
          %Client{
            client
            | token: %AccessToken{
                access_token: "new_access_token",
                expires_at: (DateTime.utc_now() |> DateTime.to_unix()) + 600,
                refresh_token: "new_refresh_token"
              }
          }
        end do
        {:ok, agent} = TokenAgent.start_link(initial_client: test_client())
        TokenAgent.refresh(agent)

        assert TokenAgent.get_access_token(agent) == "new_access_token"

        assert_called(Client.refresh_token(:_))
      end
    end

    test "uses the initial client to get a new token if no refresh token is available" do
      with_mock Client, [:passthrough],
        get_token: fn client ->
          {:ok,
           %Client{
             client
             | token: %AccessToken{
                 access_token: "test_access_token",
                 expires_at: (DateTime.utc_now() |> DateTime.to_unix()) + 600
               }
           }}
        end,
        refresh_token: fn _client -> {:error, %OAuth2.Error{reason: :econnrefused}} end,
        get_token!: fn client ->
          %Client{
            client
            | token: %AccessToken{
                access_token: "new_access_token",
                expires_at: (DateTime.utc_now() |> DateTime.to_unix()) + 600
              }
          }
        end do
        {:ok, agent} = TokenAgent.start_link(initial_client: test_client())
        TokenAgent.refresh(agent)

        assert TokenAgent.get_access_token(agent) == "new_access_token"

        assert_not_called(Client.refresh_token(:_))
      end
    end

    test "uses the initial client to get a new token if no token is available" do
      with_mock Client, [:passthrough],
        get_token: fn client ->
          {:ok, client}
        end,
        refresh_token: fn _client -> {:error, %OAuth2.Error{reason: :econnrefused}} end,
        get_token!: fn client ->
          %Client{
            client
            | token: %AccessToken{
                access_token: "new_access_token",
                expires_at: (DateTime.utc_now() |> DateTime.to_unix()) + 600
              }
          }
        end do
        {:ok, agent} = TokenAgent.start_link(initial_client: test_client())
        TokenAgent.refresh(agent)

        assert TokenAgent.get_access_token(agent) == "new_access_token"

        assert_not_called(Client.refresh_token(:_))
      end
    end
  end

  describe "inline refresh" do
    test "triggers during get_access_token if the inline_refresh strategy requires it" do
      with_mock Client, [:passthrough],
        get_token: fn client ->
          {:ok,
           %Client{
             client
             | token: %AccessToken{
                 access_token: "test_access_token",
                 expires_at: (DateTime.utc_now() |> DateTime.to_unix()) + 10,
                 refresh_token: "test_refresh_token"
               }
           }}
        end,
        refresh_token: fn client ->
          {:ok,
           %Client{
             client
             | token: %AccessToken{
                 access_token: "new_access_token",
                 expires_at: (DateTime.utc_now() |> DateTime.to_unix()) + 6000,
                 refresh_token: "new_refresh_token"
               }
           }}
        end do
        {:ok, agent} =
          TokenAgent.start_link(
            initial_client: test_client(),
            inline_refresh_strategy: %TokenRefreshStrategy{
              seconds_before_expires: 30
            }
          )

        assert TokenAgent.get_access_token(agent) == "new_access_token"
      end
    end

    test "does not trigger during get_access_token if the inline_refresh strategy does not require it" do
      with_mock Client, [:passthrough],
        get_token: fn client ->
          {:ok,
           %Client{
             client
             | token: %AccessToken{
                 access_token: "test_access_token",
                 expires_at: (DateTime.utc_now() |> DateTime.to_unix()) + 100,
                 refresh_token: "test_refresh_token"
               }
           }}
        end,
        refresh_token: fn client ->
          {:ok,
           %Client{
             client
             | token: %AccessToken{
                 access_token: "new_access_token",
                 expires_at: (DateTime.utc_now() |> DateTime.to_unix()) + 6000,
                 refresh_token: "new_refresh_token"
               }
           }}
        end do
        {:ok, agent} =
          TokenAgent.start_link(
            initial_client: test_client(),
            inline_refresh_strategy: %TokenRefreshStrategy{
              seconds_before_expires: 30
            }
          )

        assert TokenAgent.get_access_token(agent) == "test_access_token"

        assert_not_called(Client.refresh_token(:_))
      end
    end

    test "does not trigger during get_access_token if no inline_refresh strategy is set" do
      with_mock Client, [:passthrough],
        get_token: fn client ->
          {:ok,
           %Client{
             client
             | token: %AccessToken{
                 access_token: "test_access_token",
                 expires_at: (DateTime.utc_now() |> DateTime.to_unix()) + 10,
                 refresh_token: "test_refresh_token"
               }
           }}
        end,
        refresh_token: fn client ->
          {:ok,
           %Client{
             client
             | token: %AccessToken{
                 access_token: "new_access_token",
                 expires_at: (DateTime.utc_now() |> DateTime.to_unix()) + 6000,
                 refresh_token: "new_refresh_token"
               }
           }}
        end do
        {:ok, agent} =
          TokenAgent.start_link(initial_client: test_client(), inline_refresh_strategy: nil)

        assert TokenAgent.get_access_token(agent) == "test_access_token"

        assert_not_called(Client.refresh_token(:_))
      end
    end
  end
end
