defmodule Tesla.Middleware.BasicAuth do
  @moduledoc """
  Basic authentication middleware.

  [Wiki on the topic](https://en.wikipedia.org/wiki/Basic_access_authentication)

  ## Examples

  ```
  defmodule MyClient do
    use Tesla

    # static configuration
    plug Tesla.Middleware.BasicAuth, username: "user", password: "pass"

    # dynamic configuration
    plug Tesla.Middleware.BasicAuth, username: {:foo, :user}, {:foo, :pass}
    plug Tesla.Middleware.BasicAuth, username: {:foo, :user, "user"}, {:foo, :pass, "pass"}
    plug Tesla.Middleware.BasicAuth, username: "user", &get_pass/1
    plug Tesla.Middleware.BasicAuth, &get_auth/1

    # dynamic user & pass
    def new(username, password, opts \\\\ %{}) do
      Tesla.client [
        {Tesla.Middleware.BasicAuth, Map.merge(%{username: username, password: password}, opts)}
      ]
    end

    defp get_pass(_key) do
      Application.get_env(:foo, :pass)
    end
  end
  ```

  ## Options

  The input takes a map or keyword list with the following keys:

  Simple string configuration:
  - `:username` - string (defaults to `""`)
  - `:password` - string (defaults to `""`)

  Read from Application environment:
  - `:username` - {:the_app, :config_key}
  - `:username` - {:the_app, :config_key, "default"}

  - `:password` - {:the_app, :config_key}
  - `:password` - {:the_app, :config_key, "default"}

  Call a function:
  - `:username` - Function with arity 1
  - `:password` - Function with arity 1

  You can also specify a function which returns a map.
  """

  @behaviour Tesla.Middleware

  @impl Tesla.Middleware
  def call(env, next, opts) do
    opts = opts || %{}

    env
    |> Tesla.put_headers(authorization_header(opts))
    |> Tesla.run(next)
  end

  defp authorization_header(opts) do
    opts
    |> authorization_vars()
    |> encode()
    |> create_header()
  end

  @spec authorization_vars(Keyword.t() | map() | function()) :: map()
  def authorization_vars(fun) when is_function(fun) do
    fun.()
  end

  def authorization_vars(opts) when is_map(opts) or is_list(opts) do
    for key <- [:username, :password], into: %{} do
      authorization_var(key, opts[key] || "")
    end
  end

  defp authorization_var(key, {app, config_key}) do
    {key, Application.get_env(app, config_key, "")}
  end

  defp authorization_var(key, {app, config_key, default}) do
    {key, Application.get_env(app, config_key, default)}
  end

  defp authorization_var(key, val) when is_function(val) do
    {key, val.(key)}
  end

  defp authorization_var(key, val) do
    {key, val}
  end

  defp create_header(auth) do
    [{"authorization", "Basic #{auth}"}]
  end

  defp encode(%{username: username, password: password}) do
    Base.encode64("#{username}:#{password}")
  end
end
