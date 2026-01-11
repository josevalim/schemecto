defmodule SchemectoTest do
  use ExUnit.Case
  doctest Schemecto

  # Helper functions for validation
  defp validate_address(changeset, params) do
    changeset
    |> Ecto.Changeset.cast(params, [:street, :city, :zip])
    |> Ecto.Changeset.validate_required([:street, :city])
  end

  defp validate_address_with_length(changeset, params) do
    changeset
    |> Ecto.Changeset.cast(params, [:street, :city, :zip])
    |> Ecto.Changeset.validate_required([:street, :city])
    |> Ecto.Changeset.validate_length(:zip, is: 5)
  end

  defp validate_coordinates(changeset, params) do
    changeset
    |> Ecto.Changeset.cast(params, [:lat, :lon])
    |> Ecto.Changeset.validate_required([:lat, :lon])
  end

  defp validate_address_with_coords(changeset, params) do
    changeset
    |> Ecto.Changeset.cast(params, [:street, :city, :coordinates])
    |> Ecto.Changeset.validate_required([:street, :city])
  end

  describe "new/2" do
    test "creates a schemaless changeset with empty defaults" do
      types = %{name: :string, age: :integer}
      changeset = Schemecto.new(types)

      assert %Ecto.Changeset{} = changeset
      assert changeset.data == %{}
      assert changeset.types == types
      assert changeset.valid?
    end

    test "creates a schemaless changeset with defaults" do
      types = %{name: :string, age: :integer}
      defaults = %{name: "Alice"}
      changeset = Schemecto.new(types, defaults: defaults)

      assert %Ecto.Changeset{} = changeset
      assert changeset.data == defaults
      assert changeset.types == types
    end

    test "can cast params onto the changeset" do
      types = %{name: :string, age: :integer}
      changeset =
        Schemecto.new(types)
        |> Ecto.Changeset.cast(%{name: "Bob", age: 25}, [:name, :age])

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :name) == "Bob"
      assert Ecto.Changeset.get_change(changeset, :age) == 25
    end
  end

  describe "one/2" do
    test "validates nested data successfully" do
      address_types = %{street: :string, city: :string, zip: :string}

      types = %{
        name: :string,
        email: :string,
        address: Schemecto.one(address_types, with: &validate_address/2)
      }

      params = %{
        name: "John Doe",
        email: "john@example.com",
        address: %{
          street: "123 Main St",
          city: "Springfield",
          zip: "12345"
        }
      }

      changeset =
        Schemecto.new(types)
        |> Ecto.Changeset.cast(params, [:name, :email, :address])

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :name) == "John Doe"
      assert Ecto.Changeset.get_change(changeset, :email) == "john@example.com"

      address = Ecto.Changeset.get_change(changeset, :address)
      assert address.street == "123 Main St"
      assert address.city == "Springfield"
      assert address.zip == "12345"
    end

    test "handles invalid nested data" do
      address_types = %{street: :string, city: :string, zip: :string}

      types = %{
        name: :string,
        address: Schemecto.one(address_types, with: &validate_address/2)
      }

      params = %{
        name: "Jane Doe",
        address: %{
          street: "456 Oak Ave"
          # Missing required city field
        }
      }

      changeset =
        Schemecto.new(types)
        |> Ecto.Changeset.cast(params, [:name, :address])

      refute changeset.valid?
      assert {"is invalid", metadata} = changeset.errors[:address]

      assert [
        type: {:parameterized, {Schemecto.One, _},
        validation: :cast,
        city: {"can't be blank", [validation: :required]}
      ] = Enum.sort(metadata)
    end

    test "handles nil nested data" do
      address_types = %{street: :string, city: :string, zip: :string}

      types = %{
        name: :string,
        address: Schemecto.one(address_types, with: &validate_address/2)
      }

      params = %{
        name: "Jane Doe",
        address: nil
      }

      changeset =
        Schemecto.new(types)
        |> Ecto.Changeset.cast(params, [:name, :address])

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :address) == nil
    end

    test "uses defaults in nested changesets" do
      address_types = %{street: :string, city: :string, zip: :string, country: :string}

      types = %{
        name: :string,
        address: Schemecto.one(address_types, with: &validate_address/2, defaults: %{country: "US"})
      }

      params = %{
        name: "Alice",
        address: %{
          street: "123 Main",
          city: "Boston",
          zip: "02101"
        }
      }

      changeset =
        Schemecto.new(types)
        |> Ecto.Changeset.cast(params, [:name, :address])

      assert changeset.valid?

      address = Ecto.Changeset.get_change(changeset, :address)
      assert address.street == "123 Main"
      assert address.city == "Boston"
      assert address.zip == "02101"
      assert address.country == "US"
    end
  end

  describe "many/2" do
    test "raises not implemented error" do
      assert_raise RuntimeError, "Schemecto.many/2 is not yet implemented", fn ->
        Schemecto.many(%{}, fn _, _ -> nil end)
      end
    end
  end
end
