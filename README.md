# OAuth2TokenManager

This package works with the `oauth2` package to manage the automatic renewal of
tokens before they expire

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `oauth2_token_manager` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:oauth2_token_manager, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/oauth2_token_manager>.

## Usage

Create an `OAuth2.Client` instance to use to get the initial token and pass it to
`OAuth2TokenMananger.TokenAgent.start_link/1` along with the inline
`OAuth2TokenManager.TokenRefreshStrategy` and the name for the `Agent`.

The client can be configured as described at
https://github.com/ueberauth/oauth2#configure-a-http-client.

```Elixir
client = Client.new([
      strategy: OAuth2.Strategy.ClientCredentials,
      client_id: "example_client_id",
      client_secret: "example_client_secret",
      site: "https://example.com/"
    ])

{:ok, agent} = OAuth2TokenManager.TokenAgent.start_link(
  name: MyModule.TokenAgent,
  initial_client: client,
  inline_refresh_strategy: %OAuth2TokenManager.TokenRefreshStrategy{seconds_before_expires: 30}
)
```

The current version of the client can be retrieved using
`OAuth2TokenManager.TokenAgent.get_client/1` with the agent's PID or name.  
This client will automatically use the access token as a Bearer token in
the Authorization header when calling its request methods. The access token
itself can be retrieved from the client struct if it is desirable to use separately
configured clients and `OAuth2TokenManager.TokenAgent.get_access_token/1` is
provided for convenience when doing so.

```Elixir
current_client = OAuth2TokenManager.TokenAgent.get_client(agent)
current_client = OAuth2TokenManager.TokenAgent.get_client(MyModule.TokenAgent)
access_token = OAuth2TokenManager.TokenAgent.get_access_token(MyModule.TokenAgent)
```

The token can be refreshed by calling `OAuth2TokenManager.TokenAgent.refresh_tokens/1`.
If a refresh token is available, it will be exchanged for a new set of tokens.
If no refresh token is available or the attempt to use the refresh results in an error,
the original client will be used again to attempt to obtain a new set of tokens.

```Elixir
:ok = OAuth2TokenManager.TokenAgent.refresh(MyModule.TokenAgent)
```

This can be used to handle complex token refresh logic, but it will generally be
preferable to configure [a strategy](#inline-token-refresh-strategies).

### Inline Token Refresh Strategies

Inline token refresh strategies are used to determine when to obtain a new token
before returning the current client state or token value. The supported conditions
are show in the below example.

```Elixir
%TokenRefreshStrategy{
  seconds_before_expires: 30, # refresh the token if it will expire in the next N seconds
  every_seconds: 300 # refresh the token if it has been at least N seconds since the last refresh
}
```

If the Authorization Server does not provide an expiration time for the token, the
expiration time conditions will not trigger a refresh, so `:every_seconds` should
be used.

The inline refreshes only occur as part of request for data from the agent; this
saves unnecessary renewal requests in low-volume systems but tokens may be allowed
to expire if unused. If refresh tokens need to be kept active in a system where the
time between requests exceeds the token duration and the initial client cannot be
reused, using `OAuth2TokenManager.TokenAgent.refresh` may be necessary.

The inline refreshes occur during message processing in the agent, which is not
concurrent per agent. This guarantees that redundant refresh calls will not be
made, which is particularly important when using single-use refresh tokens, but
also adds the latency of the refresh to the processing of the message that
triggers it.

The same strategy can have properties configured for multiple conditions and the
token will be refreshed if any of them are met.

If no value is specified when starting the agent, the behavior defaults to
`%TokenRefreshStrategy{seconds_before_expires: 30, every_seconds: 300}`.

### Configuring a Singleton

Providing a name for the agent allows it to be referred to in code without passing
around the PID, which is useful for reusing the same token whenever providing
credentials for the same principal, cutting down on the number of calls that need
to be made to the Authorization Server. A named instance can be added to a
supervision tree's children using a tuple like the below example. This will
launch the agent under the supervision tree and restart it if it crashes.

```Elixir
children = [
  {TokenAgent, name: MyModule.TokenAgent, initial_client: client}
]

```
