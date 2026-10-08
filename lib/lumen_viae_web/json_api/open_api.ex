defmodule LumenViaeWeb.JsonApi.OpenApi do
  @moduledoc """
  Corrects the OpenAPI document AshJsonApi generates for `/api/v2`, so that
  a client generated from it (Apple's swift-openapi-generator, or
  openapi-generator's Kotlin generator) can call every route and decode
  every response the server actually sends.

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
      way to send `fields[...]`, and so no way to ask for signed audio. (No
      parameter is left as a `deepObject` now: see `fields` below.)
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
    * **`fields` is one parameter per type.** Generated as a single
      `deepObject` parameter, an object with a key per type. A request is
      `fields[meditation]=title,narrations` either way, but a Kotlin
      generator cannot send a `deepObject` (Retrofit has no such encoding,
      and the object class it writes does not compile), where it sends a
      parameter named `fields[meditation]` as it is told. The wire is the
      same.
    * **`included` is a named, inherited schema.** Generated as a list of
      an inline `oneOf` over the resources that can be included. Kotlin
      reads a `oneOf` as a sealed class whose members do not extend it, and
      cannot be compiled or decoded. So `included_resource` is the `oneOf`
      (discriminated on `type`, which is what Swift reads), each member is
      `included_<type>`, `allOf` the resource and `included_base`, and the
      base carries the `type` discriminator and its mapping, which is what
      makes a Kotlin generator write a sealed class the members extend.
    * **No attribute is required.** Generated with the attributes Ash will
      not leave empty marked `required`, which is true of a response that
      names no `fields` and false of one that does: `fields[mystery]=name`
      answers a mystery with no `category`, and a generated client refuses
      it. Left to the resource's own `type` and `id`.
    * **A list is a list.** Generated with `uniqueItems: true` on every
      array of resources, which a Kotlin generator reads as a `Set`. A set's
      meditations are in prayer order and a set has no order.

    * **A calculation that is never null is not `nullable`.** Generated
      with every field outside `required` marked nullable, and a
      calculation is never in `required`, so a mystery's `key` and every
      section of the content document read as nullable though the
      resource says `allow_nil? false`. A field that is not asked for is
      left out, never null.
    * **A list argument's `max_length` is its `maxItems`.** Generated
      without it, so `POST /meditations/audio` did not say that it takes
      at most 200 ids.
    * **No `include` where nothing can be included.** Generated on every
      operation, with a pattern that matches only the empty string; any
      path named there is a 400.
    * **No input a route does not offer.** A set by id is not narrowed by
      a category: `:visible`'s `category` argument is the list's, and
      GraphQL hides it on the get the same way.

  One change follows the API rather than correcting AshJsonApi: the list
  of sets takes no `include` (`LumenViaeWeb.JsonApi.QueryParams` refuses
  one), so its operation has no `include` parameter and its response no
  `included` list.

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

  alias LumenViaeWeb.JsonApi.QueryParams

  @doc """
  The `modify_open_api` callback: `spec` corrected as described above.
  """
  def modify(%OpenApi{} = spec, _conn, opts) do
    routes = Enum.flat_map(opts[:domains], &AshJsonApi.Domain.Info.routes/1)
    spec = %{spec | security: [], components: Map.delete(spec.components, :securitySchemes)}
    %{components: %{schemas: schemas} = components} = spec = normalize(spec)
    schemas = Map.new(schemas, &(&1 |> pin_type() |> never_null(routes)))
    responses = Map.new(components.responses, &wrap_errors/1)
    no_includes = Enum.map(QueryParams.lists_without_includes(), &("/api/v2" <> &1))
    included = included_variants(spec.paths)

    paths =
      Map.new(spec.paths, fn {path, item} ->
        item = if path in no_includes, do: without_includes(item), else: item

        item =
          item
          |> map_operations(&drop_unused_include/1)
          |> map_operations(&drop_hidden_inputs/1)
          |> map_operations(&limit_lists(&1, routes))

        {path, describe_types(item, schemas)}
      end)

    schemas = Map.merge(schemas, included_schemas(included))
    %{spec | components: %{components | schemas: schemas, responses: responses}, paths: paths}
  end

  defp map_operations(%PathItem{} = item, fun) do
    Enum.reduce([:get, :post, :patch, :delete], item, fn verb, item ->
      case Map.fetch!(item, verb) do
        %Operation{} = operation -> Map.put(item, verb, fun.(operation))
        nil -> item
      end
    end)
  end

  # An operation whose responses can include nothing offers no `include`.
  defp drop_unused_include(%Operation{} = operation) do
    if Enum.any?(Map.values(operation.responses), &included_schema/1) do
      operation
    else
      %{
        operation
        | parameters: Enum.reject(operation.parameters, &(to_string(&1.name) == "include"))
      }
    end
  end

  # Inputs an action takes that its route does not offer, by operation.
  @hidden_inputs %{"getMeditationSet" => ["category"]}

  defp drop_hidden_inputs(%Operation{operationId: id} = operation) do
    hidden = Map.get(@hidden_inputs, id, [])
    %{operation | parameters: Enum.reject(operation.parameters, &(to_string(&1.name) in hidden))}
  end

  # A request body's list argument says how many items it takes.
  defp limit_lists(%Operation{requestBody: %{content: content} = body} = operation, routes) do
    case route_action(routes, operation.operationId) do
      nil ->
        operation

      action ->
        limits =
          for %{type: {:array, _}, constraints: constraints} = argument <- action.arguments,
              max = constraints[:max_length],
              into: %{},
              do: {to_string(argument.name), max}

        content =
          Map.new(content, fn {type, media} ->
            {type, %{media | schema: limit_body(media.schema, limits)}}
          end)

        %{operation | requestBody: %{body | content: content}}
    end
  end

  defp limit_lists(operation, _routes), do: operation

  defp route_action(routes, name) do
    case Enum.find(routes, &(&1.name == name)) do
      nil -> nil
      route -> Ash.Resource.Info.action(route.resource, route.action)
    end
  end

  # A generic action's arguments are the body's `data`; a create's are in
  # `data.attributes`.
  defp limit_body(%Schema{properties: %{data: %Schema{} = data}} = schema, limits) do
    data =
      case data.properties do
        %{attributes: %Schema{} = attributes} ->
          put_in(data.properties.attributes, limit_properties(attributes, limits))

        _other ->
          limit_properties(data, limits)
      end

    put_in(schema.properties.data, data)
  end

  defp limit_body(schema, _limits), do: schema

  defp limit_properties(%Schema{properties: properties} = schema, limits) do
    properties =
      Map.new(properties, fn {name, property} ->
        key = to_string(name)

        case limits do
          %{^key => max} -> {name, %{property | maxItems: max}}
          _none -> {name, property}
        end
      end)

    %{schema | properties: properties}
  end

  # A resource's calculations that are never null are not nullable.
  defp never_null(
         {name, %Schema{properties: %{attributes: %Schema{} = attributes}} = schema},
         routes
       ) do
    case Enum.find(routes, &(AshJsonApi.Resource.Info.type(&1.resource) == name)) do
      nil ->
        {name, schema}

      route ->
        not_null =
          for calculation <- Ash.Resource.Info.public_calculations(route.resource),
              not calculation.allow_nil?,
              do: to_string(calculation.name)

        properties =
          Map.new(attributes.properties, fn {field, property} ->
            if to_string(field) in not_null,
              do: {field, not_nullable(property)},
              else: {field, property}
          end)

        {name, put_in(schema.properties.attributes, %{attributes | properties: properties})}
    end
  end

  defp never_null(entry, _routes), do: entry

  defp not_nullable(%Schema{} = schema), do: %{schema | nullable: nil}
  defp not_nullable(%{} = map), do: Map.drop(map, ["nullable", :nullable])

  # A list that takes no `include`: no parameter for it, and no `included`
  # in what it answers.
  defp without_includes(%PathItem{get: %Operation{} = operation} = item) do
    responses =
      Map.new(operation.responses, fn {status, response} ->
        case response do
          %{content: %{"application/vnd.api+json" => %{schema: %Schema{} = schema} = content}} ->
            schema = %{schema | properties: Map.delete(schema.properties, :included)}

            {status,
             %{
               response
               | content: %{
                   response.content
                   | "application/vnd.api+json" => %{content | schema: schema}
                 }
             }}

          _other ->
            {status, response}
        end
      end)

    %{
      item
      | get: %{
          operation
          | parameters: Enum.reject(operation.parameters, &(to_string(&1.name) == "include")),
            responses: responses
        }
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

  # A resource object's schema: its `type` can only be its own name, and
  # none of its attributes is certain to be there, because a client may ask
  # for fewer (`fields[mystery]=name` carries no `category`).
  defp pin_type(
         {name,
          %Schema{
            properties: %{type: %Schema{} = type, attributes: %Schema{} = attributes} = properties
          } = schema}
       ) do
    properties = %{
      properties
      | type: %{type | enum: [name]},
        attributes: %{attributes | required: nil}
    }

    {name, %{schema | properties: properties}}
  end

  defp pin_type(entry), do: entry

  defp describe_types(%PathItem{} = item, schemas),
    do: map_operations(item, &describe_types(&1, schemas))

  defp describe_types(%Operation{} = operation, schemas) do
    included = included_types(operation)

    %{
      operation
      | parameters: Enum.flat_map(operation.parameters, &describe_fields(&1, included, schemas)),
        responses: Map.new(operation.responses, &reference_included/1)
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

  # Every operation that includes anything includes the same resources (the
  # one set route), so one `included_resource` serves them all. A second
  # route that includes something else needs its own, and must say so here
  # rather than be given the wrong list.
  defp included_variants(paths) do
    variants =
      for {_path, item} <- paths,
          verb <- [:get, :post, :patch, :delete],
          %Operation{} = operation <- [Map.fetch!(item, verb)],
          variants = included_types(operation),
          variants != [],
          uniq: true,
          do: Enum.sort(variants)

    case variants do
      [] ->
        []

      [only] ->
        only

      _several ->
        raise "operations include different resources (#{inspect(variants)}): " <>
                "name an included schema for each in LumenViaeWeb.JsonApi.OpenApi"
    end
  end

  defp included_schemas([]), do: %{}

  defp included_schemas(types) do
    mapping = Map.new(types, &{&1, "#/components/schemas/included_#{&1}"})
    discriminator = %Discriminator{propertyName: "type", mapping: mapping}

    members =
      Map.new(types, fn type ->
        {"included_#{type}",
         %Schema{
           allOf: [
             %Reference{"$ref": "#/components/schemas/included_base"},
             %Reference{"$ref": "#/components/schemas/#{type}"}
           ]
         }}
      end)

    Map.merge(members, %{
      "included_base" => %Schema{
        type: :object,
        required: [:type],
        properties: %{type: %Schema{type: :string}},
        discriminator: discriminator
      },
      "included_resource" => %Schema{
        oneOf: Enum.map(mapping, fn {_type, ref} -> %Reference{"$ref": ref} end),
        discriminator: discriminator
      }
    })
  end

  defp reference_included({status, response}) do
    case included_schema(response) do
      %Schema{items: %Schema{oneOf: [_ | _]}} = included ->
        content = response.content["application/vnd.api+json"]
        schema = content.schema
        items = %Reference{"$ref": "#/components/schemas/included_resource"}

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

  # One `fields[<type>]` parameter for each type the response can carry.
  defp describe_fields(
         %Parameter{name: "fields", schema: %Schema{} = schema},
         included,
         schemas
       ) do
    schema.properties
    |> Map.keys()
    |> Enum.concat(included)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn type ->
      %Parameter{
        name: "fields[#{type}]",
        in: :query,
        required: false,
        style: :form,
        explode: false,
        description:
          "Comma separated fields of #{type}: #{Enum.join(field_names(schemas[type]), ", ")}",
        schema: %Schema{type: :string}
      }
    end)
  end

  defp describe_fields(parameter, _included, _schemas), do: [parameter]

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
    |> drop_unique_items()
    |> then(&if(open?, do: allow_unknown_keys(&1), else: &1))
    |> drop_empty_included()
    |> collapse_null()
  end

  defp type_string_enum(%Schema{type: nil, enum: [_ | _] = values} = schema) do
    if Enum.all?(values, &is_binary/1), do: %{schema | type: :string}, else: schema
  end

  defp type_string_enum(schema), do: schema

  defp drop_unique_items(%Schema{uniqueItems: true} = schema), do: %{schema | uniqueItems: nil}

  defp drop_unique_items(%{"uniqueItems" => true} = map), do: Map.delete(map, "uniqueItems")
  defp drop_unique_items(%{uniqueItems: true} = map), do: Map.delete(map, :uniqueItems)
  defp drop_unique_items(schema), do: schema

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
