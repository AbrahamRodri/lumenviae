defmodule LumenViaeWeb.JsonApi.OpenApi do
  @moduledoc """
  Corrects the OpenAPI document AshJsonApi generates for `/api/v2`, so that
  a client generated from it (Apple's swift-openapi-generator) can call
  every route and decode every response the server actually sends.

  Every change is to the description of the API, never to what it does: the
  routes, the actions and the responses are AshJsonApi's. Each one is a
  place where the generated document, as of AshJsonApi 1.7, describes the
  API differently from how it behaves, or in a form the generator rejects:

    * **A response may carry keys it does not list.** The schemas say
      `additionalProperties: false`, yet every response carries `links`,
      `meta` and `jsonapi` the schemas do not list, and a generated client
      refuses an object with a key it was not told about. That is also the
      rule the unversioned API lives by (docs/IOS_API_CONTRACT.md): adding
      a key must never break a build already installed. Request bodies stay
      closed, because the server does refuse a key it does not take.
    * **Null is `nullable`.** The document declares OpenAPI 3.0 but spells
      an optional value as `anyOf: [{type: null}, ...]`, which is 3.1, and
      which the generator cannot parse in a 3.0 document at all.
    * **Path parameters are `simple`**, as OpenAPI requires. Generated as
      `form`, which the generator skips, leaving `getMeditationSet` with
      no way to name the set.
    * **`deepObject` parameters explode**, as OpenAPI requires. Generated
      with `explode: false`, which the generator skips, leaving a client no
      way to send `fields[...]`, and so no way to ask for signed audio.
    * **No `included` where nothing can be included.** Generated as a list
      of `oneOf: []`, a schema that matches nothing.
    * **An error response is an object.** Generated as a bare list of
      errors; every error the server sends is `{"errors": [...]}`, as
      JSON:API says.
    * **An enum of strings is a string.** Generated with no type, which a
      generator reads as any value at all.
    * **No bearer token.** Generated for every operation; the API has no
      authentication.
    * **Each resource's `type` is its one value**, and an `included` list
      is discriminated on it. Generated as any string, in a `oneOf` with no
      discriminator, a decoder takes the first variant that fits, so an
      included mystery (which has an `order`) would be read as a set
      membership.
    * **`fields` names every type a response can carry.** Generated with
      the requested type alone, and with the fields spelled as Ash spells
      them rather than as the response does, so a client could not ask for
      an included meditation's signed narrations without going around its
      own types.

  Applied by `LumenViaeWeb.JsonApiRouter` through AshJsonApi's
  `modify_open_api` option, so the served document and the committed
  `priv/openapi/v2.json` are both the corrected one. See docs/JSON_API.md.
  """

  alias OpenApiSpex.Discriminator
  alias OpenApiSpex.OpenApi
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Parameter
  alias OpenApiSpex.PathItem
  alias OpenApiSpex.Reference
  alias OpenApiSpex.Schema

  @doc """
  The `modify_open_api` callback: `spec` corrected as described above.
  """
  def modify(%OpenApi{} = spec, _conn, _opts) do
    spec = %{spec | security: [], components: Map.delete(spec.components, :securitySchemes)}
    %{components: %{schemas: schemas} = components} = spec = normalize(spec)
    schemas = Map.new(schemas, &pin_type/1)
    responses = Map.new(components.responses, &wrap_errors/1)

    %{
      spec
      | components: %{components | schemas: schemas, responses: responses},
        paths: Map.new(spec.paths, fn {path, item} -> {path, describe_types(item, schemas)} end)
    }
  end

  defp wrap_errors(
         {name,
          %{content: %{"application/vnd.api+json" => %{schema: errors} = content}} = response}
       ) do
    schema = %Schema{type: :object, required: [:errors], properties: %{errors: errors}}

    {name,
     %{
       response
       | content: %{response.content | "application/vnd.api+json" => %{content | schema: schema}}
     }}
  end

  defp wrap_errors(entry), do: entry

  # A resource object's schema: its `type` can only be its own name.
  defp pin_type(
         {name,
          %Schema{properties: %{type: %Schema{} = type, attributes: _} = properties} = schema}
       ) do
    {name, %{schema | properties: %{properties | type: %{type | enum: [name]}}}}
  end

  defp pin_type(entry), do: entry

  defp describe_types(%PathItem{} = item, schemas) do
    Enum.reduce([:get, :post, :patch, :delete], item, fn verb, item ->
      case Map.fetch!(item, verb) do
        %Operation{} = operation -> Map.put(item, verb, describe_types(operation, schemas))
        nil -> item
      end
    end)
  end

  defp describe_types(%Operation{} = operation, schemas) do
    included = included_types(operation)

    %{
      operation
      | parameters: Enum.map(operation.parameters, &describe_fields(&1, included, schemas)),
        responses: Map.new(operation.responses, &discriminate_included/1)
    }
  end

  defp included_types(%Operation{responses: responses}) do
    responses
    |> Map.values()
    |> Enum.flat_map(fn response ->
      case included_schema(response) do
        %Schema{items: %Schema{oneOf: variants}} -> Enum.map(variants, &referenced_name/1)
        _none -> []
      end
    end)
    |> Enum.uniq()
  end

  defp included_schema(%{content: %{"application/vnd.api+json" => %{schema: schema}}}) do
    case schema do
      %Schema{properties: %{included: included}} -> included
      _other -> nil
    end
  end

  defp included_schema(_response), do: nil

  defp referenced_name(%Reference{"$ref": "#/components/schemas/" <> name}), do: name

  defp discriminate_included({status, response}) do
    case included_schema(response) do
      %Schema{items: %Schema{oneOf: variants} = items} = included ->
        mapping = Map.new(variants, fn ref -> {referenced_name(ref), ref."$ref"} end)
        items = %{items | discriminator: %Discriminator{propertyName: "type", mapping: mapping}}
        content = response.content["application/vnd.api+json"]
        schema = content.schema

        schema = %{
          schema
          | properties: %{schema.properties | included: %{included | items: items}}
        }

        {status,
         %{
           response
           | content: %{
               response.content
               | "application/vnd.api+json" => %{content | schema: schema}
             }
         }}

      _none ->
        {status, response}
    end
  end

  defp describe_fields(
         %Parameter{name: "fields", schema: %Schema{} = schema} = parameter,
         included,
         schemas
       ) do
    types = Enum.uniq(Map.keys(schema.properties) ++ included)

    properties =
      Map.new(types, fn type ->
        {type,
         %Schema{
           type: :string,
           description:
             "Comma separated fields of #{type}: #{Enum.join(field_names(schemas[type]), ", ")}"
         }}
      end)

    %{parameter | schema: %{schema | properties: properties, example: nil}}
  end

  defp describe_fields(parameter, _included, _schemas), do: parameter

  defp field_names(%Schema{properties: properties}) do
    for section <- [:attributes, :relationships],
        %Schema{properties: fields} when is_map(fields) <- [properties[section]],
        name <- Map.keys(fields) |> Enum.sort(),
        do: to_string(name)
  end

  # `open?` says whether an object may carry keys its schema does not
  # list. Everything the server sends may; a request body may not, because
  # the server refuses one with a key it does not take.
  defp normalize(term, open? \\ true)

  defp normalize(%Operation{} = operation, open?) do
    %{walk_struct(operation, open?) | requestBody: normalize(operation.requestBody, false)}
  end

  defp normalize(%Parameter{} = parameter, open?) do
    parameter
    |> fix_parameter_style()
    |> walk_struct(open?)
  end

  defp normalize(%Schema{} = schema, open?) do
    schema
    |> walk_struct(open?)
    |> fix_schema(open?)
  end

  defp normalize(%_{} = struct, open?), do: walk_struct(struct, open?)

  defp normalize(map, open?) when is_map(map) do
    map
    |> Map.new(fn {key, value} -> {key, normalize(value, open?)} end)
    |> fix_schema(open?)
  end

  defp normalize(list, open?) when is_list(list), do: Enum.map(list, &normalize(&1, open?))
  defp normalize(value, _open?), do: value

  defp walk_struct(%module{} = struct, open?) do
    fields =
      struct
      |> Map.from_struct()
      |> Map.new(fn {key, value} -> {key, normalize(value, open?)} end)

    struct(module, fields)
  end

  defp fix_parameter_style(%Parameter{in: :path} = parameter),
    do: %{parameter | style: :simple, explode: false}

  defp fix_parameter_style(%Parameter{style: :deepObject} = parameter),
    do: %{parameter | explode: true}

  defp fix_parameter_style(parameter), do: parameter

  # A schema arrives as a %Schema{} or as a plain map, with atom keys or,
  # from AshJsonApi's handling of optional fields, string keys. All get
  # the same fixes.
  defp fix_schema(schema, open?) do
    schema
    |> type_string_enum()
    |> then(&if(open?, do: allow_unknown_keys(&1), else: &1))
    |> drop_empty_included()
    |> collapse_null()
  end

  defp type_string_enum(%Schema{type: nil, enum: [_ | _] = values} = schema) do
    if Enum.all?(values, &is_binary/1), do: %{schema | type: :string}, else: schema
  end

  defp type_string_enum(schema), do: schema

  defp allow_unknown_keys(%Schema{additionalProperties: false} = schema),
    do: %{schema | additionalProperties: nil}

  defp allow_unknown_keys(%{"additionalProperties" => false} = map),
    do: Map.delete(map, "additionalProperties")

  defp allow_unknown_keys(%{additionalProperties: false} = map),
    do: Map.delete(map, :additionalProperties)

  defp allow_unknown_keys(schema), do: schema

  defp drop_empty_included(%Schema{properties: %{included: included} = properties} = schema) do
    if matches_nothing?(included),
      do: %{schema | properties: Map.delete(properties, :included)},
      else: schema
  end

  defp drop_empty_included(schema), do: schema

  defp matches_nothing?(%Schema{items: %Schema{oneOf: []}}), do: true
  defp matches_nothing?(%Schema{items: %{oneOf: []}}), do: true
  defp matches_nothing?(_schema), do: false

  # `anyOf: [{type: null}, schema]` becomes `schema` marked nullable, and
  # keeps the description that was on the wrapper.
  defp collapse_null(%{"anyOf" => variants} = wrapper) when is_list(variants) do
    case Enum.reject(variants, &null_schema?/1) do
      [only] when length(variants) == 2 ->
        only
        |> nullable()
        |> put_description(wrapper["description"])

      _ ->
        wrapper
    end
  end

  defp collapse_null(%Schema{anyOf: variants} = wrapper) when is_list(variants) do
    case Enum.reject(variants, &null_schema?/1) do
      [only] when length(variants) == 2 ->
        only
        |> nullable()
        |> put_description(wrapper.description)

      _ ->
        wrapper
    end
  end

  defp collapse_null(schema), do: schema

  defp null_schema?(%{"type" => "null"}), do: true
  defp null_schema?(%Schema{type: :null}), do: true
  defp null_schema?(_schema), do: false

  defp nullable(%Schema{} = schema), do: %{schema | nullable: true}
  defp nullable(%Reference{} = reference), do: %Schema{allOf: [reference], nullable: true}
  defp nullable(%{} = map), do: Map.put(map, "nullable", true)

  defp put_description(schema, nil), do: schema

  defp put_description(%Schema{description: nil} = schema, text),
    do: %{schema | description: text}

  defp put_description(%Schema{} = schema, _text), do: schema
  defp put_description(%{} = map, text), do: Map.put_new(map, "description", text)
end
