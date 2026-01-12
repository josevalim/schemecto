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

  defp validate_address_simple(changeset, params) do
    changeset
    |> Ecto.Changeset.cast(params, [:street, :city])
    |> Ecto.Changeset.validate_required([:street, :city])
  end

  describe "new/1" do
    test "creates a schemaless changeset with empty defaults" do
      fields = [
        %{name: :name, type: :string},
        %{name: :age, type: :integer}
      ]

      changeset = Schemecto.new(fields)

      assert %Ecto.Changeset{} = changeset
      assert changeset.data == %{}
      assert changeset.types == %{name: :string, age: :integer}
      assert changeset.valid?
    end

    test "creates a schemaless changeset with defaults" do
      fields = [
        %{name: :name, type: :string, default: "Alice"},
        %{name: :age, type: :integer}
      ]

      changeset = Schemecto.new(fields)

      assert %Ecto.Changeset{} = changeset
      assert changeset.data == %{name: "Alice"}
      assert changeset.types == %{name: :string, age: :integer}
    end

    test "can cast params onto the changeset" do
      fields = [
        %{name: :name, type: :string},
        %{name: :age, type: :integer}
      ]

      changeset =
        Schemecto.new(fields)
        |> Ecto.Changeset.cast(%{name: "Bob", age: 25}, [:name, :age])

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :name) == "Bob"
      assert Ecto.Changeset.get_change(changeset, :age) == 25
    end
  end

  describe "one/2" do
    test "validates nested data successfully" do
      address_fields = [
        %{name: :street, type: :string},
        %{name: :city, type: :string},
        %{name: :zip, type: :string}
      ]

      fields = [
        %{name: :name, type: :string},
        %{name: :email, type: :string},
        %{name: :address, type: Schemecto.one(address_fields, with: &validate_address/2)}
      ]

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
        Schemecto.new(fields)
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
      address_fields = [
        %{name: :street, type: :string},
        %{name: :city, type: :string},
        %{name: :zip, type: :string}
      ]

      fields = [
        %{name: :name, type: :string},
        %{name: :address, type: Schemecto.one(address_fields, with: &validate_address/2)}
      ]

      params = %{
        name: "Jane Doe",
        address: %{
          street: "456 Oak Ave"
          # Missing required city field
        }
      }

      changeset =
        Schemecto.new(fields)
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
      address_fields = [
        %{name: :street, type: :string},
        %{name: :city, type: :string},
        %{name: :zip, type: :string}
      ]

      fields = [
        %{name: :name, type: :string},
        %{name: :address, type: Schemecto.one(address_fields, with: &validate_address/2)}
      ]

      params = %{
        name: "Jane Doe",
        address: nil
      }

      changeset =
        Schemecto.new(fields)
        |> Ecto.Changeset.cast(params, [:name, :address])

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :address) == nil
    end

    test "uses defaults in nested changesets" do
      address_fields = [
        %{name: :street, type: :string},
        %{name: :city, type: :string},
        %{name: :zip, type: :string},
        %{name: :country, type: :string, default: "US"}
      ]

      fields = [
        %{name: :name, type: :string},
        %{name: :address, type: Schemecto.one(address_fields, with: &validate_address/2)}
      ]

      params = %{
        name: "Alice",
        address: %{
          street: "123 Main",
          city: "Boston",
          zip: "02101"
        }
      }

      changeset =
        Schemecto.new(fields)
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
      tag_fields = [
        %{name: :name, type: :string},
        %{name: :color, type: :string}
      ]

      fields = [
        %{name: :title, type: :string},
        %{name: :tags, type: Schemecto.many(tag_fields, with: &validate_tag/2)}
      ]

      params = %{
        title: "My Post",
        tags: [
          %{name: "elixir", color: "purple"},
          %{name: "ecto", color: "blue"},
          %{name: "testing", color: "green"}
        ]
      }

      changeset =
        Schemecto.new(fields)
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
      tag_fields = [
        %{name: :name, type: :string},
        %{name: :color, type: :string}
      ]

      fields = [
        %{name: :title, type: :string},
        %{name: :tags, type: Schemecto.many(tag_fields, with: &validate_tag/2)}
      ]

      params = %{
        title: "My Post",
        tags: [
          %{name: "elixir", color: "purple"},
          # Missing required name
          %{color: "blue"}
        ]
      }

      changeset =
        Schemecto.new(fields)
        |> Ecto.Changeset.cast(params, [:title, :tags])

      refute changeset.valid?
      assert {"is invalid", metadata} = changeset.errors[:tags]

      # Check that errors are nested under :errors key with indices
      assert metadata[:errors] == [{1, [name: {"can't be blank", [validation: :required]}]}]
      assert metadata[:validation] == :cast
      assert {:parameterized, {Schemecto.Many, _}} = metadata[:type]
    end

    test "handles nil for many" do
      tag_fields = [
        %{name: :name, type: :string},
        %{name: :color, type: :string}
      ]

      fields = [
        %{name: :title, type: :string},
        %{name: :tags, type: Schemecto.many(tag_fields, with: &validate_tag/2)}
      ]

      params = %{
        title: "My Post",
        tags: nil
      }

      changeset =
        Schemecto.new(fields)
        |> Ecto.Changeset.cast(params, [:title, :tags])

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :tags) == nil
    end

    test "handles empty list" do
      tag_fields = [
        %{name: :name, type: :string},
        %{name: :color, type: :string}
      ]

      fields = [
        %{name: :title, type: :string},
        %{name: :tags, type: Schemecto.many(tag_fields, with: &validate_tag/2)}
      ]

      params = %{
        title: "My Post",
        tags: []
      }

      changeset =
        Schemecto.new(fields)
        |> Ecto.Changeset.cast(params, [:title, :tags])

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :tags) == []
    end

    test "uses defaults in nested changesets for many" do
      tag_fields = [
        %{name: :name, type: :string},
        %{name: :color, type: :string},
        %{name: :priority, type: :integer, default: 0}
      ]

      fields = [
        %{name: :title, type: :string},
        %{name: :tags, type: Schemecto.many(tag_fields, with: &validate_tag/2)}
      ]

      params = %{
        title: "My Post",
        tags: [
          %{name: "elixir", color: "purple"},
          %{name: "ecto", color: "blue"}
        ]
      }

      changeset =
        Schemecto.new(fields)
        |> Ecto.Changeset.cast(params, [:title, :tags])

      assert changeset.valid?

      [tag1, tag2] = Ecto.Changeset.get_change(changeset, :tags)

      assert tag1.priority == 0
      assert tag2.priority == 0
    end
  end

  describe "integration" do
    test "one nested inside many" do
      # Define fields for the nested address (one)
      address_fields = [
        %{name: :street, type: :string},
        %{name: :city, type: :string},
        %{name: :zip, type: :string}
      ]

      # Define fields for the person that includes a nested address (one)
      person_fields = [
        %{name: :name, type: :string},
        %{name: :address, type: Schemecto.one(address_fields, with: &validate_address/2)}
      ]

      # Top level has a list of people (many)
      fields = [
        %{name: :company, type: :string},
        %{name: :employees, type: Schemecto.many(person_fields, with: &validate_person/2)}
      ]

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
        Schemecto.new(fields)
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

  describe "to_json_schema/1" do
    test "converts all basic types to JSON schema properties" do
      fields = [
        %{name: :name, type: :string},
        %{name: :age, type: :integer},
        %{name: :score, type: :float},
        %{name: :price, type: :decimal},
        %{name: :active, type: :boolean},
        %{name: :metadata, type: :map},
        %{name: :tags, type: {:array, :string}},
        %{name: :priorities, type: {:array, :integer}},
        %{name: :items, type: {:array, :any}}
      ]

      changeset = Schemecto.new(fields)
      result = Schemecto.to_json_schema(changeset)

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "name" => %{"type" => "string"},
                 "age" => %{"type" => "integer"},
                 "score" => %{"type" => "number"},
                 "price" => %{"type" => "number"},
                 "active" => %{"type" => "boolean"},
                 "metadata" => %{"type" => "object"},
                 "tags" => %{"type" => "array", "items" => %{"type" => "string"}},
                 "priorities" => %{"type" => "array", "items" => %{"type" => "integer"}},
                 "items" => %{"type" => "array", "items" => %{}}
               }
             }
    end

    test "converts nested one type to JSON schema" do
      address_fields = [
        %{name: :street, type: :string},
        %{name: :city, type: :string},
        %{name: :zip, type: :string}
      ]

      fields = [
        %{name: :name, type: :string},
        %{name: :address, type: Schemecto.one(address_fields, with: &validate_address/2)}
      ]

      changeset = Schemecto.new(fields)
      result = Schemecto.to_json_schema(changeset)

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "name" => %{"type" => "string"},
                 "address" => %{
                   "type" => "object",
                   "properties" => %{
                     "street" => %{"type" => "string"},
                     "city" => %{"type" => "string"},
                     "zip" => %{"type" => "string"}
                   },
                   "required" => ["street", "city"]
                 }
               }
             }
    end

    test "converts nested many type to JSON schema" do
      tag_fields = [
        %{name: :name, type: :string},
        %{name: :color, type: :string}
      ]

      fields = [
        %{name: :title, type: :string},
        %{name: :tags, type: Schemecto.many(tag_fields, with: &validate_tag/2)}
      ]

      changeset = Schemecto.new(fields)
      result = Schemecto.to_json_schema(changeset)

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "title" => %{"type" => "string"},
                 "tags" => %{
                   "type" => "array",
                   "items" => %{
                     "type" => "object",
                     "properties" => %{
                       "name" => %{"type" => "string"},
                       "color" => %{"type" => "string"}
                     },
                     "required" => ["name"]
                   }
                 }
               }
             }
    end

    test "converts deeply nested types to JSON schema" do
      address_fields = [
        %{name: :street, type: :string},
        %{name: :city, type: :string}
      ]

      person_fields = [
        %{name: :name, type: :string},
        %{name: :address, type: Schemecto.one(address_fields, with: &validate_address_simple/2)}
      ]

      fields = [
        %{name: :company, type: :string},
        %{name: :employees, type: Schemecto.many(person_fields, with: &validate_person/2)}
      ]

      changeset = Schemecto.new(fields)
      result = Schemecto.to_json_schema(changeset)

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "company" => %{"type" => "string"},
                 "employees" => %{
                   "type" => "array",
                   "items" => %{
                     "type" => "object",
                     "properties" => %{
                       "name" => %{"type" => "string"},
                       "address" => %{
                         "type" => "object",
                         "properties" => %{
                           "street" => %{"type" => "string"},
                           "city" => %{"type" => "string"}
                         },
                         "required" => ["street", "city"]
                       }
                     },
                     "required" => ["name"]
                   }
                 }
               }
             }
    end

    test "converts custom Ecto types to JSON schema" do
      fields = [
        %{name: :custom_name, type: Schemecto.Test.CustomString},
        %{name: :regular_name, type: :string}
      ]

      changeset = Schemecto.new(fields)
      result = Schemecto.to_json_schema(changeset)

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "custom_name" => %{"type" => "string"},
                 "regular_name" => %{"type" => "string"}
               }
             }
    end

    test "adds required fields to JSON schema" do
      fields = [
        %{name: :name, type: :string},
        %{name: :age, type: :integer},
        %{name: :email, type: :string}
      ]

      changeset =
        Schemecto.new(fields)
        |> Ecto.Changeset.validate_required([:name, :email])

      result = Schemecto.to_json_schema(changeset)

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "name" => %{"type" => "string"},
                 "age" => %{"type" => "integer"},
                 "email" => %{"type" => "string"}
               },
               "required" => ["name", "email"]
             }
    end

    test "converts Ecto.Enum string types to JSON schema" do
      fields = [
        %{
          name: :status,
          type: Ecto.ParameterizedType.init(Ecto.Enum, values: [:pending, :active, :completed])
        }
      ]

      changeset = Schemecto.new(fields)
      result = Schemecto.to_json_schema(changeset)

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "status" => %{
                   "type" => "string",
                   "enum" => ["pending", "active", "completed"]
                 }
               }
             }
    end

    test "converts Ecto.Enum integer types to JSON schema" do
      fields = [
        %{
          name: :priority,
          type: Ecto.ParameterizedType.init(Ecto.Enum, values: [low: 1, medium: 2, high: 3])
        }
      ]

      changeset = Schemecto.new(fields)
      result = Schemecto.to_json_schema(changeset)

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "priority" => %{
                   "type" => "integer",
                   "enum" => [1, 2, 3]
                 }
               }
             }
    end
  end

  describe "to_json_schema + validations" do
    test "extracts format validation to pattern" do
      fields = [%{name: :email, type: :string}]

      changeset =
        Schemecto.new(fields)
        |> Ecto.Changeset.validate_format(:email, ~r/@/)

      result = Schemecto.to_json_schema(changeset)

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "email" => %{"type" => "string", "pattern" => "@"}
               }
             }
    end

    test "extracts inclusion validation to enum for lists" do
      fields = [%{name: :status, type: :string}]

      changeset =
        Schemecto.new(fields)
        |> Ecto.Changeset.validate_inclusion(:status, ["pending", "active", "completed"])

      result = Schemecto.to_json_schema(changeset)

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "status" => %{"type" => "string", "enum" => ["pending", "active", "completed"]}
               }
             }
    end

    test "extracts inclusion validation with range to min/max" do
      fields = [%{name: :age, type: :integer}]

      changeset =
        Schemecto.new(fields)
        |> Ecto.Changeset.validate_inclusion(:age, 0..120)

      result = Schemecto.to_json_schema(changeset)

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "age" => %{"type" => "integer", "minimum" => 0, "maximum" => 120}
               }
             }
    end

    test "extracts length validation for strings with min/max" do
      fields = [%{name: :title, type: :string}]

      changeset =
        Schemecto.new(fields)
        |> Ecto.Changeset.validate_length(:title, min: 1, max: 100)

      result = Schemecto.to_json_schema(changeset)

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "title" => %{"type" => "string", "minLength" => 1, "maxLength" => 100}
               }
             }
    end

    test "extracts length validation for strings with is" do
      fields = [%{name: :code, type: :string}]

      changeset =
        Schemecto.new(fields)
        |> Ecto.Changeset.validate_length(:code, is: 6)

      result = Schemecto.to_json_schema(changeset)

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "code" => %{"type" => "string", "minLength" => 6, "maxLength" => 6}
               }
             }
    end

    test "extracts length validation for arrays" do
      fields = [%{name: :tags, type: {:array, :string}}]

      changeset =
        Schemecto.new(fields)
        |> Ecto.Changeset.validate_length(:tags, min: 1, max: 5)

      result = Schemecto.to_json_schema(changeset)

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "tags" => %{
                   "type" => "array",
                   "items" => %{"type" => "string"},
                   "minItems" => 1,
                   "maxItems" => 5
                 }
               }
             }
    end

    test "extracts number validations" do
      fields = [%{name: :age, type: :integer}]

      changeset =
        Schemecto.new(fields)
        |> Ecto.Changeset.validate_number(:age, greater_than_or_equal_to: 0, less_than: 150)

      result = Schemecto.to_json_schema(changeset)

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "age" => %{"type" => "integer", "minimum" => 0, "exclusiveMaximum" => 150}
               }
             }
    end

    test "extracts subset validation for array items" do
      fields = [%{name: :tags, type: {:array, :string}}]

      changeset =
        Schemecto.new(fields)
        |> Ecto.Changeset.validate_subset(:tags, ["elixir", "erlang", "ecto"])

      result = Schemecto.to_json_schema(changeset)

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "tags" => %{
                   "type" => "array",
                   "items" => %{"type" => "string", "enum" => ["elixir", "erlang", "ecto"]}
                 }
               }
             }
    end

    test "handles multiple validations on same field" do
      fields = [%{name: :title, type: :string}]

      changeset =
        Schemecto.new(fields)
        |> Ecto.Changeset.validate_length(:title, min: 1)
        |> Ecto.Changeset.validate_length(:title, max: 100)
        |> Ecto.Changeset.validate_format(:title, ~r/^[A-Z]/)

      result = Schemecto.to_json_schema(changeset)

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "title" => %{
                   "type" => "string",
                   "minLength" => 1,
                   "maxLength" => 100,
                   "pattern" => "^[A-Z]"
                 }
               }
             }
    end

    test "handles nested validations in one/many" do
      address_fields = [
        %{name: :street, type: :string},
        %{name: :zip, type: :string}
      ]

      validate_address = fn changeset, params ->
        changeset
        |> Ecto.Changeset.cast(params, [:street, :zip])
        |> Ecto.Changeset.validate_required([:street])
        |> Ecto.Changeset.validate_length(:zip, is: 5)
      end

      fields = [
        %{name: :name, type: :string},
        %{name: :address, type: Schemecto.one(address_fields, with: validate_address)}
      ]

      changeset = Schemecto.new(fields)
      result = Schemecto.to_json_schema(changeset)

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "name" => %{"type" => "string"},
                 "address" => %{
                   "type" => "object",
                   "properties" => %{
                     "street" => %{"type" => "string"},
                     "zip" => %{"type" => "string", "minLength" => 5, "maxLength" => 5}
                   },
                   "required" => ["street"]
                 }
               }
             }
    end

    test "raises when format validation on non-string field" do
      fields = [%{name: :age, type: :integer}]

      changeset =
        Schemecto.new(fields)
        |> Ecto.Changeset.validate_format(:age, ~r/\d+/)

      assert_raise ArgumentError, "validate_format can only be applied to string fields", fn ->
        Schemecto.to_json_schema(changeset)
      end
    end

    test "extracts metadata fields to JSON schema" do
      fields = [
        %{name: :name, type: :string, title: "Full Name", description: "The user's full name"},
        %{name: :age, type: :integer, description: "Age in years"},
        %{name: :legacy_field, type: :string, deprecated: true}
      ]

      changeset = Schemecto.new(fields)
      result = Schemecto.to_json_schema(changeset)

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "name" => %{
                   "type" => "string",
                   "title" => "Full Name",
                   "description" => "The user's full name"
                 },
                 "age" => %{
                   "type" => "integer",
                   "description" => "Age in years"
                 },
                 "legacy_field" => %{
                   "type" => "string",
                   "deprecated" => true
                 }
               }
             }
    end

    test "raises error for unknown type" do
      fields = [%{name: :name, type: :unknown_type}]
      changeset = Schemecto.new(fields)

      assert_raise ArgumentError, "unknown type given to to_json_schema: :unknown_type", fn ->
        Schemecto.to_json_schema(changeset)
      end
    end
  end
end
