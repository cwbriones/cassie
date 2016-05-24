defmodule Cassie.Migration do
  defstruct [
      up: nil,
      down: nil,
      description: nil,
      authored_at: nil,
      applied_at: nil,
      filename: nil,
    ]
end
