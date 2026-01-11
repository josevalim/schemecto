defmodule Schemecto do
  @moduledoc """
  Schemaless Ecto changesets with support for nesting and JSON Schemas.
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

    if not is_function(function, 2) do
      raise ArgumentError,
            "expected :with option to be a 2-arity function, got: #{inspect(function)}"
    end

    Ecto.ParameterizedType.init(Schemecto.One, %{types: types, with: function, defaults: defaults})
  end

  @doc """
  Defines a nested validation for cardinality :many.

  ## Parameters

    * `types` - Map of field names to their types for the nested changeset
    * `opts` - Keyword list of options:
      * `:with` - A 2-arity function that receives a changeset and params,
        and returns a validated changeset (required)
      * `:defaults` - Default values for each nested changeset (default: `%{}`)

  ## Examples

      def validate_tag(changeset, params) do
        changeset
        |> Ecto.Changeset.cast(params, [:name, :color])
        |> Ecto.Changeset.validate_required([:name])
      end

      types = %{
        title: :string,
        tags: Schemecto.many(
          %{name: :string, color: :string},
          with: &validate_tag/2
        )
      }

      changeset =
        Schemecto.new(types)
        |> Ecto.Changeset.cast(params, [:title, :tags])

  """
  def many(types, opts) when is_map(types) and is_list(opts) do
    function = Keyword.fetch!(opts, :with)
    defaults = Keyword.get(opts, :defaults, %{})

    if not is_function(function, 2) do
      raise ArgumentError,
            "expected :with option to be a 2-arity function, got: #{inspect(function)}"
    end

    Ecto.ParameterizedType.init(Schemecto.Many, %{
      types: types,
      with: function,
      defaults: defaults
    })
  end

  @doc """
  Converts a changeset's types into a JSON schema.

  Takes a changeset and returns a JSON schema based on the changeset's metadata.

  Note the "$schema" property is not included in the schema for easier embedding,
  but it is recommended to be set to "https://json-schema.org/draft/2020-12/schema".

  ## Examples

      iex> types = %{name: :string, age: :integer}
      iex> changeset = Schemecto.new(types)
      iex> Schemecto.to_json_schema(changeset)
      %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        }
      }

  """
  def to_json_schema(%Ecto.Changeset{types: types, required: required, validations: validations}) do
    properties =
      Map.new(types, fn {field, type} ->
        schema =
          validations
          |> Keyword.get_values(field)
          |> Enum.reduce(type_to_json_schema(type), &apply_validation/2)

        {to_string(field), schema}
      end)

    result = %{
      "type" => "object",
      "properties" => properties
    }

    if required == [] do
      result
    else
      required_fields = Enum.map(required, &to_string/1)
      Map.put(result, "required", required_fields)
    end
  end

  defp type_to_json_schema({:parameterized, {Ecto.Enum, params}} = type) do
    Ecto.Enum.type(params)
    |> type_to_json_schema()
    |> Map.put("enum", Ecto.Enum.dump_values(%{field: type}, :field))
  end

  defp type_to_json_schema({:parameterized, {Schemecto.One, one}}) do
    %{types: types, with: fun, defaults: defaults} = one

    Ecto.Changeset.change({defaults, types})
    |> fun.(%{})
    |> to_json_schema()
  end

  defp type_to_json_schema({:parameterized, {Schemecto.Many, many}}) do
    %{types: types, with: fun, defaults: defaults} = many

    %{
      "type" => "array",
      "items" =>
        Ecto.Changeset.change({defaults, types})
        |> fun.(%{})
        |> to_json_schema()
    }
  end

  # For all other types, get the underlying type using Ecto.Type.type/1
  defp type_to_json_schema(type) do
    try do
      Ecto.Type.type(type)
    rescue
      UndefinedFunctionError ->
        raise ArgumentError, "unknown type given to to_json_schema: #{inspect(type)}"
    else
      type -> do_type_to_json_schema(type)
    end
  end

  defp do_type_to_json_schema(:string), do: %{"type" => "string"}
  defp do_type_to_json_schema(:integer), do: %{"type" => "integer"}
  defp do_type_to_json_schema(:float), do: %{"type" => "number"}
  defp do_type_to_json_schema(:boolean), do: %{"type" => "boolean"}
  defp do_type_to_json_schema(:map), do: %{"type" => "object"}

  defp do_type_to_json_schema({:array, :any}) do
    %{
      "type" => "array",
      "items" => %{}
    }
  end

  defp do_type_to_json_schema({:array, inner_type}) do
    %{
      "type" => "array",
      "items" => type_to_json_schema(inner_type)
    }
  end

  defp do_type_to_json_schema(unknown) do
    raise ArgumentError, "unknown type given to to_json_schema: #{inspect(unknown)}"
  end

  # Validation appliers for each type

  defp apply_validation({:format, regex}, schema) do
    unless schema["type"] == "string" do
      raise ArgumentError, "validate_format can only be applied to string fields"
    end

    Map.put(schema, "pattern", Regex.source(regex))
  end

  defp apply_validation({:inclusion, values}, schema) when is_list(values) do
    Map.put(schema, "enum", values)
  end

  defp apply_validation({:inclusion, first..last//1}, schema) do
    schema
    |> Map.put("minimum", first)
    |> Map.put("maximum", last)
  end

  defp apply_validation({:length, opts}, schema) do
    case schema["type"] do
      "string" -> apply_string_length(schema, opts)
      "array" -> apply_array_length(schema, opts)
      "object" -> apply_object_length(schema, opts)
      _ -> schema
    end
  end

  defp apply_validation({:number, opts}, schema) do
    Enum.reduce(opts, schema, fn
      {:greater_than, val}, acc -> Map.put(acc, "exclusiveMinimum", val)
      {:less_than, val}, acc -> Map.put(acc, "exclusiveMaximum", val)
      {:greater_than_or_equal_to, val}, acc -> Map.put(acc, "minimum", val)
      {:less_than_or_equal_to, val}, acc -> Map.put(acc, "maximum", val)
      {:equal_to, val}, acc -> Map.put(acc, "const", val)
      _unknown, acc -> acc
    end)
  end

  defp apply_validation({:subset, values}, schema) do
    update_in(schema["items"], fn items ->
      Map.put(items || %{}, "enum", values)
    end)
  end

  defp apply_validation(_unknown, schema), do: schema

  defp maybe_put(schema, _key, nil), do: schema
  defp maybe_put(schema, key, value), do: Map.put(schema, key, value)

  # Type-specific length handlers

  defp apply_string_length(schema, opts) do
    schema
    |> maybe_put("minLength", opts[:is] || opts[:min])
    |> maybe_put("maxLength", opts[:is] || opts[:max])
  end

  defp apply_array_length(schema, opts) do
    schema
    |> maybe_put("minItems", opts[:is] || opts[:min])
    |> maybe_put("maxItems", opts[:is] || opts[:max])
  end

  defp apply_object_length(schema, opts) do
    schema
    |> maybe_put("minProperties", opts[:is] || opts[:min])
    |> maybe_put("maxProperties", opts[:is] || opts[:max])
  end
end
