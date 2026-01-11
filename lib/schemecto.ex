defmodule Schemecto do
  @moduledoc """
  Builds schemaless changesets, with support for nesting
  and JSON conversion.
  """

  @doc """
  Creates a new schemaless changeset with the given types.

  ## Parameters

    * `types` - Map of field names to their types
    * `opts` - Keyword list of options:
      * `:defaults` - Default values for the changeset (default: `%{}`)

  ## Examples

      types = %{name: :string, age: :integer}
      changeset = Schemecto.new(types)
      changeset = Ecto.Changeset.cast(changeset, %{name: "John", age: 30}, [:name, :age])

      # With defaults
      changeset = Schemecto.new(types, defaults: %{age: 0})

  """
  def new(types, opts \\ []) when is_map(types) and is_list(opts) do
    defaults = Keyword.get(opts, :defaults, %{})
    Ecto.Changeset.change({defaults, types}, %{})
  end

  @doc """
  Defines a nested validation for cardinality `one`.

  ## Parameters

    * `types` - Map of field names to their types for the nested changeset
    * `opts` - Keyword list of options:
      * `:with` - A 2-arity function that receives a changeset and params,
        and returns a validated changeset (required)
      * `:defaults` - Default values for the nested changeset (default: `%{}`)

  ## Examples

      def validate_address(changeset, params) do
        changeset
        |> Ecto.Changeset.cast(params, [:street, :city, :zip])
        |> Ecto.Changeset.validate_required([:street, :city])
      end

      types = %{
        name: :string,
        email: :string,
        address: Schemecto.one(
          %{street: :string,
            city: :string,
            zip: :string
          },
          with: &validate_address/2
        )
      }

      changeset =
        Schemecto.new(types)
        |> Ecto.Changeset.cast(params, [:name, :email, :address])

  """
  def one(types, opts) when is_map(types) and is_list(opts) do
    function = Keyword.fetch!(opts, :with)
    defaults = Keyword.get(opts, :defaults, %{})

    unless is_function(function, 2) do
      raise ArgumentError,
            "expected :with option to be a 2-arity function, got: #{inspect(function)}"
    end

    Ecto.ParameterizedType.init(Schemecto.One, %{types: types, with: function, defaults: defaults})
  end

  @doc """
  Defines a nested validation for cardinality :many.

  To be implemented.
  """
  def many(_types, _function) do
    raise "Schemecto.many/2 is not yet implemented"
  end
end
