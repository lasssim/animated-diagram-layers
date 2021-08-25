# API Design Guidelines

## OpenAPI Specification

> The OpenAPI Specification, originally known as the Swagger Specification, is a
> specification for machine-readable interface files for describing, producing,
> consuming, and visualizing RESTful web services. Originally part of the
> Swagger framework, it became a separate project in 2016, overseen by the
> OpenAPI Initiative, an open source collaborative project of the Linux
> Foundation. Swagger and some other tools can generate code, documentation
> and test cases given an interface file.
>
> -- [Wikipedia](https://en.wikipedia.org/wiki/OpenAPI_Specification)

A lot of companies and projects rely on the OpenAPI Specification as it is the
de facto standard for documenting RESTful APIs. This lead to a very broad
landscape of tools and scripts for different platforms, special use-cases and
output formats. Currently, there are two versions (V2 and V3) of the OpenAPI
Specification used. Serious tools must support both of them for now.  Also, the
specification has a lot of features which makes it hard for tools to implement
all of them.

An unexpected challenge, when working with OpenAPI is to find the right set of
tools for your purpose. This section explains a tool-chain that should cover all
most needs.

> The OpenAPI specification file(s) are used as input to all tools and are
> mostly independent of the tools. This makes it easy to migrate between the
> tools and prevents vendor lock-in.

Please refer to the [OpenAPI Specification][oas3] for a detailed description
of the used attributes. Only important and special usages of attributes are
described in this document.

API documentation is stored in the `doc` directory of microservices that expose
APIs. The naming convention is `<service-name>.oas3.yaml`.

### Meta Information

The first thing to add there is the preamble.

```yaml
openapi: 3.0.0
info:
  title: Things Service
  version: '2.0'
  contact:
    name: Max Mustermann
    email: max@onlim.com
  description: API definition for the Things Service API
tags:
  - name: Things
servers:
  - url: https://example.com
```

### Index & Create path

To create the relevant paths for the Things Service API add these paths.

```yaml
paths: 
  /things/v1/things: 
    get:
      summary: Find Things
      description: Find all things
      operationId: find_things
      tags:
        - Things
      responses:
        '200':
          description: "A list of Things"
          content:
            application/json:
              schema:
                type: "array"
                items:
                  "$ref": "#/components/schemas/Thing"

    post:
      summary: Create Thing
      description: Create a thing
      operationId: create_thing
      tags:
        - Things
      responses:
        '200':
          description: "A newly created Thing"
          content:
            application/json:
              schema:
                "$ref": "#/components/schemas/Thing"
```

The attribute `operationId` is optional and can be used by code generators to
name methods accordingly, so it is advised to set it for every path.

### Show, Update & Delete paths

For the Show, Update and Delete actions create this path.

```yaml
  /things/v1/things/{id}: 
    parameters:
      - name: id
        in: path
        required: true
        schema:
          type: string

    get:
      summary: Find Thing
      description: Find one thing
      operationId: find_thing
      tags:
        - Things
      responses:
        '200':
          description: "A Thing"
          content:
            application/json:
              schema:
                "$ref": "#/components/schemas/Thing"
    put:
      summary: Replace Thing
      description: replace the whole thing
      operationId: replace_thing
      tags:
        - Things
      responses:
        '200':
          description: "The updated Thing." 
          content:
            application/json:
              schema:
                "$ref": "#/components/schemas/Thing"
      requestBody:
        content:
          application/json:
            schema:
              "$ref": "#/components/schemas/Thing"

    delete:
      summary: Delete Thing
      description: deletes a thing
      operationId: delete_thing
      tags:
        - Things
      responses:
        '204':
          description: The resource was deleted successfully.
```

### Entities

As you can see in the path definitions, the request and response schemas are
not fully defined yet, they reference to `#/components/schemas/Thing`. This
is a nice way to minimize duplication and to enforce consistent API
definitions because the definition of `Thing` is reused for all of these
endpoints.

Now it's time to create the sections for the entities.

Create the these definitions.

```yaml
components:
  schemas:
    Entity:
      type: object
      required: [id, type]
      properties:
        id:
          type: string
          format: uuid
        type:
          type: string

    Thing:
      allOf:
        - "$ref": "#/components/schemas/Entity"
        - required: [external_id, source]
          properties:
            attributes:
              type: object
              properties:
                external_id:
                  type: string
                source:
                  type: string
    Person:
      allOf:
        - "$ref": "#/components/schemas/Thing"
        - properties:
            type:
              enum: [Person]
        - properties:
            attributes:
              type: object
              properties:
                name:
                  type: string
                images:
                  type: array
                  items:
                    type: object
                    properties:
                      remote_url:
                        type: string
                url:
                  type: string
```

The general structure of an Entity (aka. Schema Object) will be discussed in the
JSON:API section below. The most important thing to mention here is the
polymorphism.


```plantuml
class Entity
class Thing
class Person 

Entity <-- Thing
Thing <-- Person
```

`Entity` here acts as the "base class" for our class hierarchy. By using the
`allOf` keyword we can compose entities and let them inherit properties from
others. 


> There is a `discriminator` keyword that can be used to define the property
> (`type`) that holds the information about the actual class. But the way way
> openapi defines the behavior of the `discriminator` is not working as needed
> to define complex class hierarchies. If one would define a hierarchy like
> this:
>
```plantuml
class Entity
class Cat
class Thing
class Person 

Entity <-- Cat
Entity <-- Thing
Thing <-- Person
```
>
> and a polymorphic interface like the `find_all` path from the example above,
> the specification would also include `Cat` entities in the response. A `Cat`
> is not a `Thing` in our case.



#### Validation of specification

You can use the `mermade.openapi-lint` Visual Studio Code extension. It gives you a command called `OpenAPI Resolve and validate`.

## JSON API

This section will pick some important parts of the JSON:API specification and
describe it in more detail. For the general documentation please refer to the
[official documentation][oas3]. You can also watch this
[video][jsonapi-video] to get an introduction.

### Entity design

Entities are designed using the [JSON:API resource
objects][jsonapi-resource-objects] and basically consist of these properties:

* *attributes*: an attributes object representing some of the resource’s data.
* *relationships*: a relationships object describing relationships between the
  resource and other JSON:API resources.
* *links*: a links object containing links related to the resource.
* *meta*: a meta object containing non-standard meta-information about a resource
  that can not be represented as an attribute or relationship.

Let's use an entity called Event and explore the JSON:API specific parts.

```yaml

allOf:
  - "$ref": "#/components/schemas/Thing"  
  - properties:
      type:
        enum: [Person]
  - properties:
      attributes:
        type: object
        properties:
          name:
            type: string
          images:
            type: array
            items:
              type: object
              properties:
                remote_url:
                  type: string
                  format: uri
          url:
            type: string
            format: uri
          startDate:
            type: string
            format: date-time
          endDate:
            type: string
            format: date-time
      relationships:
        type: object
        properties:
          organizer:
            allOf:
              - $ref: "../../../../doc/assets/api_helpers/to_one.yaml"
              - properties:
                  data:
                    properties:
                      type:
                        enum: [Person]
          performers:
            allOf:
              - $ref: "../../../../doc/assets/api_helpers/to_many.yaml"
              - properties:
                  data:
                    items:
                      properties:
                        type:
                          enum: [Person] 
```

#### Attributes

The `attributes` property holds all the attributes of the Entity.

Complex attributes are perfectly fine. As soon, as the complex attribute
behaves like a real entity (eg. queryable via API, used by many entities) you
should consider building a real entity for it and switch to using a relationship
instead.

Please refer to the [OpenAPI Schema Object] definition for all details about
data-types and validation options.

#### Relationships

In the example of the Event you can see that there are two relationships.

* *organizer*: a reference to the organizer of the event 
* *performers*: a list of Person entities that perform at the event

Please keep in mind that depending on the multiplicity, the data attribute can be of type *array* or *object*.

To make this example complete, we need to add the relationship to the other
entity (`Person`) as well.

```yaml
      relationships:
        type: object
        properties:
          events_organized:
            allOf:
              - $ref: "../../../../doc/assets/api_helpers/to_many.yaml"
              - properties:
                  data:
                    items:
                      properties:
                        type:
                          enum: [Event]
          events_performed:
            allOf:
              - $ref: "../../../../doc/assets/api_helpers/to_many.yaml"
              - properties:
                  data:
                    items:
                      properties:
                        type:
                          enum: [Event]
```

> Please take a look at the helper files for the `to_many` and `to_one`
> relationships that help with keeping the spec clean.

### Fetching Resources

The following explanations use this example. Add this code to the definition of the path `paths/things`:

```yaml

  parameters:
    # Compound document parameter
    - name: include
      in: query
      schema:
        type: string
      description: include specified relationships

    # Pagination parameters
    - $ref: "../../../../doc/assets/api_helpers/pagination.yaml#/parameters/number"
    - $ref: "../../../../doc/assets/api_helpers/pagination.yaml#/parameters/size"
    - $ref: "../../../../doc/assets/api_helpers/pagination.yaml#/parameters/offset"
    - $ref: "../../../../doc/assets/api_helpers/pagination.yaml#/parameters/limit"
 
    # Filter parameters
    - name: filter[<type>]
      in: query
      schema:
        type: string
      description: filter things for type
    - name: filter[address.addressCountry],
      in: query
      schema:
        type: string
      description: filter things for the addressCountry

    # Sparse fieldsets parameter
    - in: query
      name: fields[type]
      description: A comma separated list of fields or field-group names.
      schema:
        type: array
        items:
          type: string
        minItems: 1
```

#### Compound documents

To save HTTP request, you can use the `included` parameter to chose which
relationships should be returned along with your request. These documents are
then called [compound documents][compound-documents].

It is advised to not allow includes for resources that cross the border of the
actual service that is handling the request. This could lead to unpredictable
side effects and be a huge scaling issue. It is better to ignore the
include-parameter in that case and let the client use the related link to fetch
the data in a separate request.

#### Sorting

In addition to the JSON:API [sorting] specification you can define virtual
sorting attributes that sort based on a value that is not represented by a
dedicated attribute.

```yaml
    - name: sort,
      in: query
      description: define sort order
      schema:
        type: string
      example: ~description_length
```

Virtual sort attributes must be prefixed with a "~".

#### Filtering

##### Nested Attributes

In addition to the JSON:API [filtering] specification and their 
[recommendation article][filtering-recommendation] you can use the "." character
to filter for nested attributes withing complex fields
(`filter[address.addressCountry]`).

##### Filter Operators

Additional filter operators may be defined and added to filters to specify
behavior of the filter. This list may be extended with more operators.

* `lt` (less than)
* `lte` (less than or equal)
* `gt` (greater than)
* `gte` (greater than or equal)
* `nin` (doesn't include)
* `in` (includes)

```yaml
    - name: filter[price.lt]
      in: query
      description: filter for a price lower than the given value
      schema:
        type: integer
```

##### Virtual Filters

Filtering on conditions that are not represented by an attribute directly can be
accomplished by introducing virtual filters.

```yaml
    - name: filter[~description_length.gt]
      in: query
      description: filter for descriptions that are longer than the given value
      schema:
        type: integer
```

This example assumes that there is an attribute called description. The length
of the description is not an attribute on its own, but with the virtual filter
`~description_length` one can still filter for it.

Virtual filters must be prefixed with a "~".

##### Polymorphic type filter

When filtering for a specific `type` the expected response includes resource
objects of exactly that type. By adding the modifies `.poly`, this behavior is
changed to returning resource objects of that `type` and its sub-types.

```yaml
    - name: filter[type.poly]
      in: query
      description: filter for Things and its sub-types
      schema:
        type: string
```

##### Geo Queries

Geo queries can be accomplished by defining a virtual filter.

```yaml
    - name: filter[~geo_distance]=<lng>,<lat>,<distance>
      in: query
      description: filter for geo distance
      schema:
        type: string
```

To define a related sort order you could introduce a virtual sorting attribute
`~geo_distrance` that sorts by distance.

#####  Complex filtering

Complex filters can be achieved by using the approach described
[here][nested-filtering].

#### Pagination

In addition to the JSON:API [pagination] specification you can paginate nested
resources or included relationships by prefixing the pagination parameter with
the name of the relationship (eg. `page[performers.size]=4`).

> There is a helper file available to streamline the definition of the
> pagination parameters. Please take a look at the file to learn how pagination
> parameters are defined.

To extend the response with the pagination meta information you can use another helper like this:

```yaml
      responses:
        '200':
          description: "A list of Things"
          content:
            application/json:
              schema:
                allOf:
                  - $ref: "../../../../doc/assets/api_helpers/pagination.yaml#/meta"
                  - type: object
                    properties:
                      data:
                        type: array
                        items:
                          $ref: "#/components/schemas/Thing"
```

#### Sparse Fieldsets

In addition to the JSON:API [sparse fieldset] specification you can define
field-groups that group a set of fields together and use those in the parameter
as well.

### URL Design

JSON:API also gives a recommendation for [URL design].

This page includes a detailed description for related resources. The basic idea
is to have a primary URL for every resource that is not nested. A nested URL
may be used to fetch related resources of another resource.

### API Versioning

Use a mix of URI visioning and API evolution.

1. Prefix all URLs of a service with a version (eg. `/v1/things`)
2. Never break your APIs unless you absolutely have to (add new things or
   resources, deprecate unused bits)

This strategy will help you to avoid confusing code and APIs while keeping the
possibility alive to release a completely new version. If you need to release a
new version, strive for deprecating the older version as soon as possible.

> Allow yourself to break the API until a certain point during development
> before the first release. The more you implement, the better you can define an
> API.

More information about these concepts can be found [here][api-versioning] and
[here][api-evolution].

### Error Responses

JSON:API [defines][error-responses] that error responses may include error
objects that give more insights about the error (eg. validation errors). This
information can be used by clients to give reasonable feedback to the user. As
the content and the triggered client side behavior of these responses relies
heavily on the actual use-case it is advised to have a conversation between
backend and client engineers about error states to define proper error objects
and responses.

In OpenAPI you can easily reuse error responses. Add this to the section `/components/responses/` of your OpenAPI specification.

```yaml
components:
  responses:
    InternalServerError:
      description: The specified resource was not found
      content:
        application/json:
          schema:
            type: object
            properties:
              errors:
                type: array
                items:
                  type: object
                  properties:
                    status: 
                      type: string
                      default: "500"
                    code: 
                      type: string
                      default: "InternalServerError"
                    detail: 
                      type: string
                    source:
                      type: array
                      items:
                        type: object
                        properties:
                          id: 
                            type: string
                            format: uuid
                          type: 
                            type: string
```

Now you can add this to any path, eg `/paths/things`, to define the
`InternalServerError` response.

```yaml
    '500':
      $ref: '#/components/responses/InternalServerError'

```

### Messagebus envelope

JSON:API can also be used on a message bus level. In general, sending message on
a message bus based on state changes rather than directed messages has proven to
be very solid and clear. That means, that messages are only sent, when an Entity
was changed (created, updated or deleted). Changes are strictly only allowed to
be done by the owning microservice of that entity and therefor only this
microservice is allowed to send the messages.

```plantuml

class Message {
  String **id**
  String **type**
  Object **attributes**
    <U+251C> String **event**
    <U+251C> Time **created_at**
    <U+2514> String **created_by**
  Object **relationships**
    <U+2514> Entity **entity**
}

Message <-- Event
```

Messages are wrapped in an envelope that has a relationship to the actual
entity. By doing this, the serialization of a message using JSON:API is straight
forward.

More can be found in this [blog series][message-bus].

### Naming conventions

| Item                         | Convention                 | Example                        |
| ---                          | ---                        | ---                            |
| Resource names in URLs       | always plural, snake_case  | `/things`, `/local_businesses` |
| `type` field                 | always singular, CamelCase | `Thing`, `LocalBusiness`       |
| has_many relationship name   | plural, snake_case         | `owned_things`, `performers`   |
| has_one relationship name    | singular, snake_case       | `organizer`                    |
| belongs_to relationship name | singular, snake_case       | `owner`                        |
| attribute names              | snake_case                 | `name`, `first_name`           |


[oas3]: https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.2.md
[jsonapi]: http://www.jsonapi.org
[ReDoc]: https://redoc.ly/
[create-openapi-repo]: https://github.com/Redocly/create-openapi-repo
[nvm]: https://github.com/nvm-sh/nvm
[SwaggerUI]: https://swagger.io/tools/swagger-ui/
[openapi-generator]: https://github.com/OpenAPITools/openapi-generator
[prism-video]: https://www.youtube.com/watch?v=HvrAMCCJy70
[jsonapi-video]: https://www.youtube.com/watch?v=RSv-Yv3cgPg
[openapi-video]: https://www.youtube.com/watch?v=EjezAA7YYys
[jsonapi-resource-objects]: https://jsonapi.org/format/#document-resource-objects
[compound-documents]: https://jsonapi.org/format/1.0/#document-compound-documents
[sparse fieldset]: https://jsonapi.org/format/1.0/#fetching-sparse-fieldsets
[pagination]: https://jsonapi.org/format/1.0/#fetching-pagination
[api-versioning]: https://apisyouwonthate.com/blog/api-versioning-has-no-right-way
[api-evolution]: https://www.mnot.net/blog/2012/12/04/api-evolution.html
[error-responses]: https://jsonapi.org/format/1.0/#errors
[message-bus]: https://www.runtastic.com/blog/en/messagebus-defining-content/
[prism]: https://github.com/stoplightio/prism
[filtering-recommendation]: https://jsonapi.org/recommendations/#filtering
[OpenAPI Schema Object]: https://swagger.io/docs/specification/data-models/
[URL design]: https://jsonapi.org/recommendations/#urls
[nested-filtering]: http://www.crnk.io/releases/stable/documentation/#_nested_filtering
[sorting]: https://jsonapi.org/format/#fetching-sorting
