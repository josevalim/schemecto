# Schemecto

Schemecto provides schemaless Ecto changesets with support for nested schemaless changesets and JSON Schema generation.

## Usage

Define types and validation functions for your data structures:

```elixir
defmodule Example do
  def changeset(params) do
    types = %{
      name: :string,
      email: :string,
      address: Schemecto.one(
        %{street: :string, city: :string, zip: :string},
        with: &Example.validate_address/2
      )
    }

    Schemecto.new(types)
    |> Ecto.Changeset.cast(params, [:name, :email, :address])
    |> Ecto.Changeset.validate_required([:name, :email])
    |> Ecto.Changeset.validate_format(:email, ~r/@/)
  end

  def validate_address(changeset, params) do
    changeset
    |> Ecto.Changeset.cast(params, [:street, :city, :zip])
    |> Ecto.Changeset.validate_required([:street, :city])
    |> Ecto.Changeset.validate_length(:zip, is: 5)
  end
end
```

Since Schemecto is built on Ecto changesets, you can use all standard Ecto validation functions. The types map can be constructed dynamically at runtime, making it ideal for scenarios where the schema must be composed at runtime.

## JSON Schema Generation

Convert your changesets to JSON Schema to generate API documentation, validate client-side forms, or integrate with other tools:

```elixir
Schemecto.to_json_schema(changeset)
```

The generated schema includes required fields, format patterns, length constraints, numeric bounds, and enum fields from your changeset. For instance, the changeset above will emit:

```json
{
  "type": "object",
  "properties": {
    "address": {
      "type": "object",
      "properties": {
        "city": {
          "type": "string"
        },
        "street": {
          "type": "string"
        },
        "zip": {
          "type": "string",
          "maxLength": 5,
          "minLength": 5
        }
      },
      "required": ["street", "city"]
    },
    "email": {
      "type": "string",
      "pattern": "@"
    },
    "name": {
      "type": "string"
    }
  },
  "required": ["name", "email"]
}
```

## Installation

Add `schemecto` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:schemecto, github: "josevalim/schemecto"}
  ]
end
```

## License

Copyright 2026 José Valim

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
