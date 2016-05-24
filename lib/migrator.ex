defmodule Cassie.Migrator do
  require Logger

  defmodule MigrationError do
    defexception [message: nil]
  end

  defmodule CassandraError do
    defexception [
        error_message: nil,
        error_code: nil
      ]

    def message(%__MODULE__{error_message: message, error_code: code}) do
      "Error Code #{code}: #{message}"
    end
  end

  alias Cassie.Migration

  require Record
  import Record, only: [defrecord: 2, extract: 2]

  defrecord :cql_query, extract(:cql_query, from_lib: "cqerl/include/cqerl.hrl")

  def run(path, :up, opts) do
    ensure_migrations_table!

    to_apply =
      path
      |> migrations
      |> Enum.filter(fn %Migration{applied_at: a} -> is_nil(a) end)

    case to_apply do
      [] -> Logger.info("Already up")
      to_apply  ->
        {time, _} = :timer.tc(Enum, :each, [to_apply, &migrate(&1, :up, opts)])
        Logger.info("== Migrated in #{inspect(div(time, 10000)/10)}s")
    end
  end
  def run(path, :down, opts) do
    ensure_migrations_table!

    n = Keyword.get(opts, :n, 1)

    to_apply =
      path
      |> migrations
      |> Enum.filter(fn %Migration{applied_at: a} -> a end)
      |> Enum.reverse
      |> Enum.take(n)

    case to_apply do
      [] -> Logger.info("Already down")
      to_apply  ->
        {time, _} = :timer.tc(Enum, :each, [to_apply, &migrate(&1, :down, opts)])
        Logger.info("== Migrated in #{inspect(div(time, 10000)/10)}s")
    end
  end

  def ensure_migrations_table! do
    create_keyspace =
      "CREATE KEYSPACE cassie_migrator WITH REPLICATION = {'class' : 'SimpleStrategy', 'replication_factor': 1};"

    create_table = ~s"""
    CREATE TABLE cassie_migrator.migrations (
      authored_at timestamp,
      description varchar,
      applied_at timestamp,
      PRIMARY KEY (authored_at, description)
    );
    """
    execute_idempotent(create_keyspace)
    execute_idempotent(create_table)
  end

  def migrations(path) do
    all =
      path
      |> migrations_available
      |> Enum.map(fn mig = %Migration{authored_at: a, description: d} -> {{d, a}, mig} end)
      |> Enum.into(%{})

    applied =
      migrations_applied
      |> Enum.map(fn mig = %Migration{authored_at: a, description: d} -> {{d, a}, mig} end)
      |> Enum.into(%{})
    all
    |> Map.merge(applied, fn _k, from_file, %Migration{applied_at: a}  ->
      %Migration{from_file|applied_at: a}
    end)
    |> Map.values
    |> Enum.sort(fn %Migration{authored_at: a}, %Migration{authored_at: b} -> a < b end)
  end

  def migrations_available(path) do
    path
    |> File.ls!
    |> Enum.map(fn file ->
      Path.join(path, file) |> Cassie.Parser.parse_migration
    end)
  end

  def migrations_applied do
    "SELECT * FROM cassie_migrator.migrations;"
    |> execute
    |> Enum.map(fn mig ->
      defaults = Map.delete(%Migration{}, :__struct__)
      mig
      |> Enum.into(defaults)
      |> Map.put(:__struct__, Migration)
    end)
  end

  defp migrate(%Migration{filename: filename, down: nil}, :down, _opts) do
    raise MigrationError, message: "Rollback is not supported for migration: #{filename}"
  end
  defp migrate(mig = %Migration{filename: filename, authored_at: authored_at, description: description, up: up}, :up, opts) do
    Logger.info("== Running #{filename}")
    execute_statements(up, opts)
    query = "INSERT INTO cassie_migrator.migrations (authored_at, description, applied_at) VALUES (?, ?, ?);"
    values = [authored_at: authored_at, description: description, applied_at: System.system_time(:milli_seconds)]
    execute(query, values)
  rescue
    e in [Cassie.Migrator.CassandraError] ->
      Logger.error(Exception.message(e))
      migrate(mig, :down, opts)
      Logger.info("There was an error while trying to migrate #{filename}")
      exit(:shutdown)
  end
  defp migrate(%Migration{filename: filename, authored_at: authored_at, description: description, down: down}, :down, opts) do
    Logger.info("== Running #{filename} backwards")
    execute_statements(down, opts)
    query = "DELETE FROM cassie_migrator.migrations WHERE authored_at = ? AND description = ?;"
    values = [authored_at: authored_at, description: description]
    execute(query, values)
  end

  defp execute_statements(cql, opts) do
    cql
    |> String.split(";", trim: true)
    |> Enum.each(fn s -> execute_idempotent(s <> ";", opts) end)
    :ok
  end

  defp execute(statement, values \\ []) do
    {:ok, c} = :cqerl.get_client {}
    query = cql_query(statement: statement, values: values)
    case :cqerl.run_query(c, query) do
      {:ok, :void} -> :ok
      {:ok, result} -> :cqerl.all_rows(result)
      {:error, {8704, _, _}} -> []
      {:error, {code, msg, _}} -> raise CassandraError, query: statement, error_message: msg, error_code: code
    end
  end

  defp execute_idempotent(query, opts \\ []) do
    {:ok, c} = :cqerl.get_client {}
    if Keyword.get(opts, :log, false) do
      query_info =
        query
        |> String.split
        |> Enum.take(3)
        |> Enum.join(" ")
      Logger.info(query_info)
    end
    case :cqerl.run_query(c, query) do
      {:ok, _} -> :ok
      # These are the error codes for Already Exists and
      # Unconfigured Keyspace/Table, respectively
      {:error, {9216, _, _}} -> :ok
      {:error, {8704, _, _}} -> :ok
      {:error, {code, msg, _}} -> raise CassandraError, error_message: msg, error_code: code
    end
  end
end
