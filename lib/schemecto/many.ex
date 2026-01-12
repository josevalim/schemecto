defmodule Schemecto.Many do
  @moduledoc """
  A parameterized Ecto type for nested changeset validation with cardinality :many.

  This module implements the `Ecto.ParameterizedType` behaviour to support
  nested validation of list data. It creates a changeset with the specified
  types and applies a validation function to each element in the list.
  """

  use Ecto.ParameterizedType

  @impl true
  def type(_params), do: {:array, :map}

  @impl true
  def init(state) do
    state
  end

  @impl true
  def cast(nil, _params), do: {:ok, nil}

  def cast(values, %{changeset: changeset, with: fun}) when is_list(values) do
    keys = Map.keys(changeset.types)

    {valid_values, all_errors} =
      values
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {value, index}, {valid_acc, error_acc} ->
        if is_map(value) do
          changeset =
            if value == %{} do
              changeset
            else
              Ecto.Changeset.cast(changeset, value, keys)
            end

          case fun.(changeset) do
            %Ecto.Changeset{valid?: true} = cs ->
              {[Ecto.Changeset.apply_changes(cs) | valid_acc], error_acc}

            %Ecto.Changeset{valid?: false, errors: errors} ->
              indexed_errors = [{index, errors} | error_acc]
              {valid_acc, indexed_errors}
          end
        else
          # Not a map, add empty error list
          indexed_errors = [{index, []} | error_acc]
          {valid_acc, indexed_errors}
        end
      end)

    if Enum.empty?(all_errors) do
      # All valid, reverse to maintain original order
      {:ok, Enum.reverse(valid_values)}
    else
      # Collect all errors with their indices under :errors key
      {:error, [errors: Enum.reverse(all_errors)]}
    end
  end

  def cast(_value, _params), do: :error

  @impl true
  def load(nil, _loader, _params), do: {:ok, nil}
  def load(values, _loader, _params) when is_list(values), do: {:ok, values}
  def load(_value, _loader, _params), do: :error

  @impl true
  def dump(nil, _dumper, _params), do: {:ok, nil}
  def dump(values, _dumper, _params) when is_list(values), do: {:ok, values}
  def dump(_value, _dumper, _params), do: :error

  @impl true
  def equal?(nil, nil, _params), do: true
  def equal?(a, b, _params) when is_list(a) and is_list(b), do: a == b
  def equal?(_a, _b, _params), do: false
end
