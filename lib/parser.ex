defmodule Cassie.Parser do
  alias Cassie.Migration

  def parse_migration(filename) do
    filename
    |> File.read!
    |> String.split("\n")
    |> Enum.map(&String.strip/1)
    |> parse_loop(nil, %Migration{filename: filename})
    |> validate
    |> clean
  end

  def parse_loop([], _, params), do: params
  def parse_loop([line = "-- up:"|lines], _, params) do
    parse_loop(lines, :up, params)
  end
  def parse_loop([line = "-- down:"|lines], _, params) do
    parse_loop(lines, :down, params)
  end
  def parse_loop([line = "-- authored_at:" <> authored_at|lines], state, params) do
    {ts, _} =
      authored_at
      |> String.strip
      |> Integer.parse
    parse_loop(lines, state, %Migration{params|authored_at: ts})
  end
  def parse_loop([line = "-- description:" <> desc|lines], state, params) do
    parse_loop(lines, state, %Migration{params|description: String.strip(desc)})
  end
  def parse_loop([line|lines], state, params) do
    case line do
      "--" <> _ -> parse_loop(lines, state, params)
      _ -> parse_loop(lines, state, add_line(params, state, line))
    end
  end

  defp clean(params = %Migration{up: up, down: nil, description: desc}) do
    %Migration{params|
      up: String.strip(up),
      description: String.strip(desc)
    }
  end
  defp clean(params = %Migration{up: up, down: down, description: desc}) do
    %Migration{params|
      up: String.strip(up),
      down: String.strip(down),
      description: String.strip(desc)
    }
  end

  defp validate(params) do
    cond do
      !params.authored_at ->
        raise ArgumentError, message: "Missing \"authored_at\""
      !params.up ->
        raise ArgumentError, message: "Missing \"up\""
      !params.description ->
        raise ArgumentError, message: "Missing \"description\""
      true ->
        params
    end
  end

  def add_line(params, nil, _), do: params
  def add_line(params, :up, line) do
    current = params.up || ""
    %Migration{params|up: current <> line <> "\n"}
  end
  def add_line(params, :down, line) do
    current = params.up || ""
    %Migration{params|down: current <> line <> "\n"}
  end
end
