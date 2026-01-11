defmodule Schemecto.Test.CustomString do
  @moduledoc """
  A custom Ecto type that wraps `:string`.

  Used for testing custom type support in `to_json_schema`.
  """
  use Ecto.Type

  @impl true
  def type, do: :string

  @impl true
  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(_), do: :error

  @impl true
  def load(value) when is_binary(value), do: {:ok, value}
  def load(_), do: :error

  @impl true
  def dump(value) when is_binary(value), do: {:ok, value}
  def dump(_), do: :error
end
