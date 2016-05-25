# Cassie

Some simple Cassandra migration tasks for Mix.

# Usage
First we define our migrations. These are just ordinary CQL files in `priv/cassie` that are described via comments. For instance, we could want a table to store our import `foobar` data.

```cql
-- description: Creates the foobars table
-- authored_at: 1464076712285_create_foobars.cql
-- up:
USE test;

CREATE TABLE foobars (
  foo int,
  bar int,
  PRIMARY KEY (foo, bar)
);
-- down:
DROP TABLE foobars
```

Cassie will parse these CQL files for us, and let us view all migrations
with `cassie.migrations`.

```bash
Christian λ mix cassie.migrations
Status   Name                                    Description
---------------------------------------------------------------------------------
up       1464076712285_create_foobars.cql         Creates the foobars table
up       1464076931287_create_users_table.cql    Adds qux to foobars
up       1464078503735_add_foobar_keyspace.cql   Adds the foobar keyspace
up       1464078511522_add_baz_table.cql         Makes the table baz
```

Let's rollback that last one with `cassie.rollback`.

```
Christian λ mix cassie.rollback

01:32:32.203 [info]  == Running priv/cassie/1464078511522_add_baz_table.cql backwards

01:32:32.203 [info]  USE foobar;

01:32:32.204 [info]  DROP TABLE baz;

01:32:32.359 [info]  == Migrated in 1.5s
```

Listing them again shows the result of the rollback.

```bash
Christian λ mix cassie.migrations
Status   Name                                    Description
---------------------------------------------------------------------------------
up       1464076712285_create_foobars.cql         Creates the foobars table
up       1464076931287_create_users_table.cql    Adds qux to foobars
up       1464078503735_add_foobar_keyspace.cql   Adds the foobar keyspace
down     1464078511522_add_baz_table.cql         Makes the table baz
```

So let's undo that and apply all pending migrations with `cassie.migrate`...

```
Christian λ mix cassie.migrate

01:33:20.025 [info]  == Running priv/cassie/1464078511522_add_baz_table.cql

01:33:20.025 [info]  USE foobar;

01:33:20.026 [info]  CREATE TABLE baz

01:33:20.224 [info]  == Migrated in 1.0s
```

and show that they're all done again!

```bash
Christian λ mix cassie.migrations
Status   Name                                    Description
---------------------------------------------------------------------------------
up       1464076712285_create_foobars.cql         Creates the foobars table
up       1464076931287_create_users_table.cql    Adds qux to foobars
up       1464078503735_add_foobar_keyspace.cql   Adds the foobar keyspace
up       1464078511522_add_baz_table.cql         Makes the table baz
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add cassie to your list of dependencies in `mix.exs`:

        def deps do
          [{:cassie, "~> 0.0.1"}]
        end

  2. Ensure cassie is started before your application:

        def application do
          [applications: [:cassie]]
        end
