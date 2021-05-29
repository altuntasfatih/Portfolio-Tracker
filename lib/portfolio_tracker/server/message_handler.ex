defmodule PortfolioTracker.MessageHandler do
  require Logger
  alias PortfolioTracker.{Supervisor,Tracker}
  alias PortfolioTracker.Bot.TelegramClient

  @type instructions ::
          :create
          | :get
          | :get_detail
          | :live
          | :destroy
          | :add_stock
          | :set_alert
          | :remove_alert
          | :get_alerts
          | :delete_stock
          | :start
          | :help

  @help_file "./resource/help.md"
  @pattern " "

  def handle_message(%{from: from}=message) do
    case parse(message.text) do
      {instruction , args} ->
        log(instruction, args)

        handle(instruction,args, from)
        |> prepare_reply
        |> send_reply(from)

      _ ->
        prepare_reply({:error, :instruction_not_found})
    end
  end

  def parse("/" <> text) do
    String.trim(text)
    |> String.split(@pattern)
    |> Enum.filter(fn x -> x != "" end)
    |> parse
  end

  def parse([instruction | args]), do: {String.to_atom(instruction), args}
  def parse(_), do: []

  @spec handle(instructions, any, any) :: any
  def handle(:create, _, from) do
    case Supervisor.start(from.id) do
      {:ok, _pid} -> {:ok, :portfolio_created}
      {:error, {:already_started, _pid}} -> {:error, :portfolio_already_created}
    end
  end

  def handle(:get, _, from),
    do: convert_data(Tracker.get(from.id), fn p -> Portfolio.to_string(p) end)

  def handle(:get_detail, _, from),
    do: convert_data(Tracker.get(from.id), fn p -> Portfolio.detailed_to_string(p) end)

  def handle(:live, _, from), do: Tracker.live(from.id)

  def handle(:destroy, _, from), do: Tracker.destroy(from.id)

  def handle(:add_stock, [id, name, count, price], from) do
    with {count, _} <- Integer.parse(count),
         {price, _} <- Float.parse(price) do
      Stock.new(id, name, count, price)
      |> Tracker.add_stock(from.id)
    else
      _ -> {:error, :args_parse_error}
    end
  end

  def handle(:add_stock, _, _), do: {:error, :missing_parameter}

  def handle(:set_alert, [type, stock_id, target_price], from) do
    with {target_price, _} <- Float.parse(target_price),
         type <- String.to_atom(type) do
      Alert.new(type, stock_id, target_price)
      |> Tracker.set_alert(from.id)
    else
      _ -> {:error, :args_parse_error}
    end
  end

  def handle(:set_alert, _, _), do: {:error, :missing_parameter}

  def handle(:remove_alert, [stock_id], from), do: Tracker.remove_alert(from.id, stock_id)

  def handle(:remove_alert, _, _), do: {:error, :missing_parameter}

  def handle(:get_alerts, _, from),
    do: convert_data(Tracker.get_alerts(from.id), &Enum.join(&1))

  def handle(:delete_stock, [stock_id], from),
    do: Tracker.delete_stock(from.id, stock_id)

  def handle(:delete_stock, _, _), do: {:error, :missing_parameter}

  def handle(:help, _, _) do
    {:ok, content} = File.read(@help_file)
    {:ok, {content, [parse_mode: :markdown]}}
  end

  def handle(:start, args, from), do: handle(:help, args, from)

  def handle(_, _, _), do: {:error, :instruction_not_found}

  defp prepare_reply({:error, :portfolio_not_found}),
    do: "There is no portfolio tracker for you, You should create firstly"

  defp prepare_reply({:error, :portfolio_already_created}),
    do: "Your portfolio tracker have already created"

  defp prepare_reply({:ok, :portfolio_created}), do: "Portfolio tracker was created for you"

  defp prepare_reply({:error, :missing_parameter}),
    do: "Argumet/Arguments are missing"

  defp prepare_reply({:error, :args_parse_error}),
    do: "Argumet/Arguments formats are invalid"

  defp prepare_reply({:error, :instruction_not_found}),
    do: "Instruction does not exist"

  defp prepare_reply({:ok, reply}), do: reply
  defp prepare_reply(r), do: r

  defp log(message, []) do
    ("Incoming message -> " <> message)
    |> Logger.info()
  end

  defp log(message, args) do
    ("Incoming message -> " <> message <> ", " <> "args -> " <> Enum.join(args, ", "))
    |> Logger.info()
  end

  defp convert_data({:error, err}, _), do: {:error, err}
  defp convert_data({:ok, data}, func), do: {:ok, func.(data)}
  defp convert_data([], _), do: {:ok, "Empty"}
  defp convert_data(data, func), do: {:ok, func.(data)}

  defp send_reply(message, to) do
    TelegramClient.send(message, to)
  end
end
