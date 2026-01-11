defmodule SchemectoTest do
  use ExUnit.Case
  doctest Schemecto

  # Helper functions for validation
  defp validate_address(changeset, params) do
    changeset
    |> Ecto.Changeset.cast(params, [:street, :city, :zip])
    |> Ecto.Changeset.validate_required([:street, :city])
  end

  defp validate_tag(changeset, params) do
    changeset
    |> Ecto.Changeset.cast(params, [:name, :color])
    |> Ecto.Changeset.validate_required([:name])
  end

  defp validate_person(changeset, params) do
    changeset
    |> Ecto.Changeset.cast(params, [:name, :address])
    |> Ecto.Changeset.validate_required([:name])
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
               errors: [city: {"can't be blank", [validation: :required]}],
               type: {:parameterized, {Schemecto.One, _}},
               validation: :cast
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
        address:
          Schemecto.one(address_types, with: &validate_address/2, defaults: %{country: "US"})
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
    test "validates list of nested data successfully" do
      tag_types = %{name: :string, color: :string}

      types = %{
        title: :string,
        tags: Schemecto.many(tag_types, with: &validate_tag/2)
      }

      params = %{
        title: "My Post",
        tags: [
          %{name: "elixir", color: "purple"},
          %{name: "ecto", color: "blue"},
          %{name: "testing", color: "green"}
        ]
      }

      changeset =
        Schemecto.new(types)
        |> Ecto.Changeset.cast(params, [:title, :tags])

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :title) == "My Post"

      [tag1, tag2, tag3] = Ecto.Changeset.get_change(changeset, :tags)

      assert tag1.name == "elixir"
      assert tag1.color == "purple"
      assert tag2.name == "ecto"
      assert tag2.color == "blue"
      assert tag3.name == "testing"
      assert tag3.color == "green"
    end

    test "handles invalid nested data in list" do
      tag_types = %{name: :string, color: :string}

      types = %{
        title: :string,
        tags: Schemecto.many(tag_types, with: &validate_tag/2)
      }

      params = %{
        title: "My Post",
        tags: [
          %{name: "elixir", color: "purple"},
          # Missing required name
          %{color: "blue"}
        ]
      }

      changeset =
        Schemecto.new(types)
        |> Ecto.Changeset.cast(params, [:title, :tags])

      refute changeset.valid?
      assert {"is invalid", metadata} = changeset.errors[:tags]

      # Check that errors are nested under :errors key with indices
      assert metadata[:errors] == [{1, [name: {"can't be blank", [validation: :required]}]}]
      assert metadata[:validation] == :cast
      assert {:parameterized, {Schemecto.Many, _}} = metadata[:type]
    end

    test "handles nil for many" do
      tag_types = %{name: :string, color: :string}

      types = %{
        title: :string,
        tags: Schemecto.many(tag_types, with: &validate_tag/2)
      }

      params = %{
        title: "My Post",
        tags: nil
      }

      changeset =
        Schemecto.new(types)
        |> Ecto.Changeset.cast(params, [:title, :tags])

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :tags) == nil
    end

    test "handles empty list" do
      tag_types = %{name: :string, color: :string}

      types = %{
        title: :string,
        tags: Schemecto.many(tag_types, with: &validate_tag/2)
      }

      params = %{
        title: "My Post",
        tags: []
      }

      changeset =
        Schemecto.new(types)
        |> Ecto.Changeset.cast(params, [:title, :tags])

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :tags) == []
    end

    test "uses defaults in nested changesets for many" do
      tag_types = %{name: :string, color: :string, priority: :integer}

      types = %{
        title: :string,
        tags: Schemecto.many(tag_types, with: &validate_tag/2, defaults: %{priority: 0})
      }

      params = %{
        title: "My Post",
        tags: [
          %{name: "elixir", color: "purple"},
          %{name: "ecto", color: "blue"}
        ]
      }

      changeset =
        Schemecto.new(types)
        |> Ecto.Changeset.cast(params, [:title, :tags])

      assert changeset.valid?

      [tag1, tag2] = Ecto.Changeset.get_change(changeset, :tags)

      assert tag1.priority == 0
      assert tag2.priority == 0
    end
  end

  describe "integration" do
    test "one nested inside many" do
      # Define types for the nested address (one)
      address_types = %{street: :string, city: :string, zip: :string}

      # Define types for the person that includes a nested address (one)
      person_types = %{
        name: :string,
        address: Schemecto.one(address_types, with: &validate_address/2)
      }

      # Top level has a list of people (many)
      types = %{
        company: :string,
        employees: Schemecto.many(person_types, with: &validate_person/2)
      }

      params = %{
        company: "Acme Corp",
        employees: [
          %{
            name: "Alice",
            address: %{
              street: "123 Main St",
              city: "Boston",
              zip: "02101"
            }
          },
          %{
            name: "Bob",
            address: %{
              street: "456 Oak Ave",
              city: "Portland",
              zip: "97201"
            }
          }
        ]
      }

      changeset =
        Schemecto.new(types)
        |> Ecto.Changeset.cast(params, [:company, :employees])

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :company) == "Acme Corp"

      [alice, bob] = Ecto.Changeset.get_change(changeset, :employees)

      assert alice.name == "Alice"
      assert alice.address.street == "123 Main St"
      assert alice.address.city == "Boston"
      assert alice.address.zip == "02101"

      assert bob.name == "Bob"
      assert bob.address.street == "456 Oak Ave"
      assert bob.address.city == "Portland"
      assert bob.address.zip == "97201"
    end
  end
end
