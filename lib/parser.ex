defmodule Cassie.Migration do
  defstruct [
      up: nil,
      down: nil,
      description: nil,
      authored: nil
    ]
end
