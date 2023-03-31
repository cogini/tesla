defmodule Tesla.Middleware.Timeout do
  @moduledoc """
  Timeout HTTP request after X milliseconds.

  ## Examples

  ```
  defmodule MyClient do
    use Tesla

    plug Tesla.Middleware.Timeout, timeout: 2_000
  end
  ```

  ## Options

  - `:timeout` - number of milliseconds a request is allowed to take (defaults to `1000`)
  """

  @behaviour Tesla.Middleware

  @default_timeout 1_000
  # Optional context propagation
  @task_module if Code.ensure_loaded?(:opentelemetry_process_propagator), do: Task, else: OpentelemetryProcessPropagator.Task

  @impl Tesla.Middleware
  def call(env, next, opts) do
    opts = opts || []
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    task_module = Keyword.get(opts, :task_module, @task_module)

    task = safe_async(fn -> Tesla.run(env, next) end, task_module)

    try do
      task
      |> task_module.await(timeout)
      |> repass_error
    catch
      :exit, {:timeout, _} ->
        task_module.shutdown(task, 0)
        {:error, :timeout}
    end
  end

  defp safe_async(func, task_module) do
    task_module.async(fn ->
      try do
        {:ok, func.()}
      rescue
        e in _ ->
          {:exception, e, __STACKTRACE__}
      catch
        type, value ->
          {type, value}
      end
    end)
  end

  defp repass_error({:exception, error, stacktrace}), do: reraise(error, stacktrace)

  defp repass_error({:throw, value}), do: throw(value)

  defp repass_error({:exit, value}), do: exit(value)

  defp repass_error({:ok, result}), do: result
end
