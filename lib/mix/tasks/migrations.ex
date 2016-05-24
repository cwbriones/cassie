defmodule Mix.Tasks.Cassie.Migrations do
  use Mix.Task
  import Mix.Cassie

  alias Cassie.Migration

  def run(_args, migrations \\ &Cassie.Migrator.migrations/1) do
    Application.ensure_all_started(:cqerl)
    all = migrations.(migrations_path)

    migs = Enum.map(all, fn %Migration{filename: file, applied_at: applied, description: desc} ->
      status = if applied, do: "up", else: "down"
      name = Path.basename(file)
      [status, name, desc]
    end)

    labels = ["Status", "Name", "Description"]
    [labels|columns] = align([labels|migs], "   ", :left)
    IO.puts "\n                                   Migrations"
    IO.puts "--------------------------------------------------------------------------------------"
    IO.puts labels
    IO.puts "--------------------------------------------------------------------------------------"
    Enum.each(columns, &IO.puts/1)
  end

  defp align(fieldsbyrow, sep, alignment) do
    maxfields = Enum.map(fieldsbyrow, fn field -> length(field) end) |> Enum.max
    colwidths = Enum.map(fieldsbyrow, fn field -> field ++ List.duplicate("", maxfields - length(field)) end)
                |> List.zip
                |> Enum.map(fn column ->
                     Tuple.to_list(column) |> Enum.map(fn col-> String.length(col) end) |> Enum.max
                   end)
    Enum.map(fieldsbyrow, fn row ->
      line =
        row
        |> Enum.zip(colwidths)
        |> Enum.map(fn {field, width} -> adjust(field, width, alignment) end)
        |> Enum.join(sep)
      sep <> line
    end)
  end

  defp adjust(field, width, :left),  do: String.ljust(field, width)
  defp adjust(field, width, :right), do: String.rjust(field, width)
  defp adjust(field, width, :center),      do: :string.centre(String.to_char_list(field), width)
end
