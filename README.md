# Schemecto

Schemecto provides schemaless Ecto changesets with support for nested schemaless changesets and JSON Schema generation.

## Installation

Add `schemecto` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:schemecto, github: "josevalim/schemecto"}
  ]
end
```

## Usage

Define fields and validation functions for your data structures:

```elixir
defmodule Example do
  def changeset(params) do
    fields = [
      %{name: :name, type: :string, title: "Full Name"},
      %{name: :email, type: :string, description: "User email address"},
      %{name: :address, type: Schemecto.one(
        [
          %{name: :street, type: :string},
          %{name: :city, type: :string},
          %{name: :zip, type: :string}
        ],
        with: &Example.validate_address/1
      )}
    ]

    Schemecto.new(fields, params)
    |> Ecto.Changeset.validate_required([:name, :email])
    |> Ecto.Changeset.validate_format(:email, ~r/@/)
  end

  def validate_address(changeset) do
    changeset
    |> Ecto.Changeset.validate_required([:street, :city])
    |> Ecto.Changeset.validate_length(:zip, is: 5)
  end
end
```

Since Schemecto is built on Ecto changesets, you can use all standard Ecto validation functions. The field list can be constructed dynamically at runtime, making it ideal for scenarios where the schema must be composed at runtime. Each field definition supports metadata like title, description, deprecated, and default values.

## JSON Schema Generation

Convert your changesets to JSON Schema to generate API documentation, validate client-side forms, or integrate with other tools:

```elixir
Schemecto.to_json_schema(changeset)
```

The generated schema includes field metadata, required fields, format patterns, length constraints, numeric bounds, and enum values from your changeset. For instance, the changeset above will emit:

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
      "description": "User email address",
      "pattern": "@"
    },
    "name": {
      "type": "string",
      "title": "Full name"
    }
  },
  "required": ["name", "email"]
}
```

## Supported types

Ecto type               | JSON type
:---------------------- | :--------------------
`:integer`              | `integer`
`:float`                | `number`
`:decimal`              | `number`
`:boolean`              | `boolean`
`:string`               | `string`
`:map`                  | `object`
`{:array, type}`        | `array` of `type`
`{:array, :any}`        | `array` of `object`
`Ecto.Enum` of `type    | `enum` of `type`

Custom Ecto types and parameterized types are also supported as long as
they emit one of the types above. More types can be added in the future too.

`Schemecto.one/2` and `Schemecto.many/2` should be preferred instead of
`:map` when the fields are known upfront.

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
