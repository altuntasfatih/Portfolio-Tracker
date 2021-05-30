defmodule PortfolioTracker.BotServer do
  use GenServer
  require Logger
  alias PortfolioTracker.MessageHandler

  @client Application.get_env(:portfolio_tracker, :bot_client)

  @interval 100
  def start_link(offset) do
    GenServer.start_link(__MODULE__, offset, name: __MODULE__)
  end

  @impl true
  def init(offset) do
    call_itself()
    {:ok, offset}
  end

  @impl true
  def handle_cast({:send_message, message, to}, state) do
    {:ok, _} = @client.send(message, to)
    {:noreply, state}
  end

  @impl true
  def handle_info(:get_messages, offset) do
    {:ok, update} = @client.get_messages(offset: offset, limit: 1)
    call_itself()
    {:noreply, handle(update, offset)}
  end

  defp handle([], offset), do: offset
  defp handle([u], _), do: handle(u)
  defp handle(%{message: nil, update_id: id}), do: id + 1

  defp handle(%{message: message, update_id: id}) do
    :ok = MessageHandler.handle_message(message)
    id + 1
  end

  defp call_itself(), do: Process.send_after(self(), :get_messages, @interval)

  def send_message(message, to), do: GenServer.cast(__MODULE__, {:send_message, message, to})

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :transient
    }
  end
end
