defmodule Cassie.Parser do

  def parse_migration(filename) do
    filename
    |> File.read!
    |> String.split("\n")
    |> Enum.map(&String.strip/1)
    |> parse_loop(nil, %Params{})
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
  def parse_loop([line = "-- authored:" <> authored|lines], state, params) do
    {ts, _} =
      authored
      |> String.strip
      |> Integer.parse
    parse_loop(lines, state, %Params{params|authored: ts})
  end
  def parse_loop([line = "-- description:" <> desc|lines], state, params) do
    parse_loop(lines, state, %Params{params|description: String.strip(desc)})
  end
  def parse_loop([line|lines], state, params) do
    case line do
      "--" <> _ -> parse_loop(lines, state, params)
      _ -> parse_loop(lines, state, add_line(params, state, line))
    end
  end

  defp clean(params = %Params{up: up, down: nil, description: desc}) do
    %Params{params|
      up: String.strip(up),
      description: String.strip(desc)
    }
  end
  defp clean(params = %Params{up: up, down: down, description: desc}) do
    %Params{params|
      up: String.strip(up),
      down: String.strip(down),
      description: String.strip(desc)
    }
  end

  defp validate(params) do
    cond do
      !params.authored ->
        raise ArgumentError, message: "Missing \"authored\""
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
    %Params{params|up: current <> line <> "\n"}
  end
  def add_line(params, :down, line) do
    current = params.up || ""
    %Params{params|down: current <> line <> "\n"}
  end
end
