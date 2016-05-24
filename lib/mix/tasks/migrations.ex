defmodule Mix.Tasks.Cassie.Migrations do
  use Mix.Task
  import Mix.Cassie

  alias Cassie.Migration

  def run(_args, migrations \\ &Cassie.Migrator.migrations/1) do
    Application.ensure_all_started(:cqerl)
    all = migrations.(migrations_path)

    message = ~s"""

      Status    File                  Description
    -----------------------------------------------
    """
    <> Enum.map_join(all, fn %Migration{filename: filename, applied_at: applied_at, description: description} ->
      status = if applied_at do
        "up  "
      else
        "down"
      end
      name = Path.basename(filename)
      "  #{status}      #{name}         #{description}"
    end)

    IO.puts message
  end
end
