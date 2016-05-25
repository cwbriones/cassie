defmodule Mix.Tasks.Cassie.Migrations do
  use Mix.Task
  import Mix.Cassie

  alias Cassie.Migration

  def run(_args, migrations \\ &Cassie.Migrator.migrations/1) do
    Application.ensure_all_started(:cqerl)
    all = migrations.(migrations_path)

    rows = Enum.map(all, fn %Migration{filename: file, applied_at: applied, description: desc} ->
      status = if applied, do: "up", else: "down"
      name = Path.basename(file)
      [status, name, desc]
    end)

    labels = ["Status", "Name", "Description"]
    tabulate(
      titles: labels,
      rows: rows,
      padding: "   ",
      title_colors: %{uid: :green, ts: :yellow, banned: :red},
      row_colors: %{"Status" => fn s -> if s == "up", do: :green, else: :red end},
      align: :left
    )
  end

  def tabulate(opts) do
    titles  = Keyword.get(opts, :titles, [])
    rows    = Keyword.get(opts, :rows, [])
    align   = Keyword.get(opts, :align, :center)
    #   row_border: :inner
    #   title_border: :top_and_bottom, # bottom
    all_rows =
      [titles|rows]
      |> Enum.map(fn row ->
        Enum.map(row, &to_string/1)
      end)
      |> pad_rows
    alignment = cond do
      is_atom(align) -> List.duplicate(align, length(hd(all_rows)))
      true -> align
    end
    col_widths = column_widths(all_rows)
    table =
      all_rows
      |> transpose
      |> (fn c -> List.zip([alignment, col_widths, c]) end).()
      |> Enum.map(fn args = {a, width, cols} ->
        Enum.map(cols, &adjust(&1, width, a))
      end)
      |> transpose
    display(table, col_widths, opts)
  end

  def display([titles|rows], col_widths, opts) do
    padding = Keyword.get(opts, :padding, "")
    title_colors = Keyword.get(opts, :title_colors, %{})
    row_colors   = Keyword.get(opts, :row_colors, %{})

    border =
      col_widths
      |> Enum.map(&String.duplicate("-", &1))
      |> Enum.intersperse(String.duplicate("-", String.length(padding)))
      |> Enum.join

    colored_titles = colorize_title(titles, title_colors)
    print_row(colored_titles, padding, titles, %{})
    IO.puts border
    titles = Enum.map(titles, &String.strip/1)
    Enum.each(rows, &print_row(&1, padding, titles, row_colors))
  end

  defp colorize_title(titles, title_colors) do
    title_colors =
      title_colors
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Enum.into(%{})

    titles
    |> Enum.map(&({&1, String.strip(&1)}))
    |> Enum.map(fn {original, t} ->
      if title_colors[t] do
        colorize(original, title_colors[t])
      else
        original
      end
    end)
  end

  defp print_row(row, padding, titles, row_colors) do
    row_colors =
      row_colors
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Enum.into(%{})

    row
    |> Enum.zip(titles)
    |> Enum.map(fn {row, title} ->
      color = row_colors[title]
      cond do
        color && is_atom(color) -> colorize(row, color)
        color && is_function(color) ->
          colorize(row, color.(String.strip(row)))
        true ->
          row
      end
    end)
    |> Enum.join(padding)
    |> IO.puts
  end

  def transpose(rows) do
    rows
    |> List.zip
    |> Enum.map(&Tuple.to_list/1)
  end

  defp align(fieldsbyrow, padding, alignment) when is_atom(alignment) do
    colwidths = column_widths(fieldsbyrow)
    Enum.map(fieldsbyrow, fn row ->
      row
      |> Enum.zip(colwidths)
      |> Enum.map(fn {field, width} -> adjust(field, width, alignment) end)
      |> Enum.join(padding)
    end)
  end

  defp pad_rows(rows) do
    max_length =
      rows
      |> Enum.map(&Kernel.length/1)
      |> Enum.max
    Enum.map(rows, &(&1 ++ List.duplicate("", max_length - length(&1))))
  end

  defp column_widths(rows) do
    rows
    |> pad_rows
    |> List.zip
    |> Enum.map(fn column ->
      column
      |> Tuple.to_list
      |> Enum.map(&String.length/1)
      |> Enum.max
    end)
  end

  defp colorize(string, color) do
    IO.ANSI.format([color, string], true) |> to_string
  end

  defp adjust(field, width, :left),  do: String.ljust(field, width)
  defp adjust(field, width, :right), do: String.rjust(field, width)
  defp adjust(field, width, :center),      do: :string.centre(String.to_char_list(field), width) |> to_string
end
