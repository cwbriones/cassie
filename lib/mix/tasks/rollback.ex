defmodule Mix.Tasks.Cassie.Rollback do
  use Mix.Task
  import Mix.Cassie

  def run(_args, migrator \\ &Cassie.Migrator.run/3) do
    Application.ensure_all_started(:cqerl)
    opts = [log: true, n: 1]
    migrator.(migrations_path, :down, opts)
  end
end
