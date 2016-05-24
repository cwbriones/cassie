defmodule Mix.Tasks.Cassie.Migrate do
  use Mix.Task
  import Mix.Cassie

  def run(_args, migrator \\ &Cassie.Migrator.run/3) do
    Application.ensure_all_started(:cqerl)
    opts = [log: true]
    migrator.(migrations_path, :up, opts)
  end
end
