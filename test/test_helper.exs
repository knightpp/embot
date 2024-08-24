defmodule TestHelper do
  def start_http_server(plug) do
    options = [
      scheme: :http,
      port: 0,
      plug: fn conn, _ -> plug.(conn) end,
      startup_log: false,
      http_options: [compress: false]
    ]

    pid = ExUnit.Callbacks.start_supervised!({Bandit, options})
    {:ok, {_ip, port}} = ThousandIsland.listener_info(pid)
    %{pid: pid, url: URI.new!("http://127.0.0.1:#{port}")}
  end
end

ExUnit.start()
