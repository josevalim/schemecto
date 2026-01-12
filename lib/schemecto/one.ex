defmodule Schemecto.One do
  @moduledoc false
  use Ecto.ParameterizedType

  @impl true
  def type(_params), do: :map

  @impl true
  def init(state) do
    state
  end

  @impl true
  def cast(nil, _params), do: {:ok, nil}

  def cast(value, %{changeset: changeset, with: fun}) when is_map(value) do
    changeset =
      if value == %{} do
        changeset
      else
        Ecto.Changeset.cast(changeset, value, Map.keys(changeset.types))
      end

    case fun.(changeset) do
      %Ecto.Changeset{valid?: true} = cs ->
        {:ok, Ecto.Changeset.apply_changes(cs)}

      %Ecto.Changeset{valid?: false, errors: errors} ->
        {:error, [errors: errors]}
    end
  end

  def cast(_value, _params), do: :error

  @impl true
  def load(nil, _loader, _params), do: {:ok, nil}
  def load(value, _loader, _params) when is_map(value), do: {:ok, value}
  def load(_value, _loader, _params), do: :error

  @impl true
  def dump(nil, _dumper, _params), do: {:ok, nil}
  def dump(value, _dumper, _params) when is_map(value), do: {:ok, value}
  def dump(_value, _dumper, _params), do: :error

  @impl true
  def equal?(nil, nil, _params), do: true
  def equal?(a, b, _params) when is_map(a) and is_map(b), do: a == b
  def equal?(_a, _b, _params), do: false
end
