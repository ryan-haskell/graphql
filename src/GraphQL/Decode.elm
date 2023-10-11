module GraphQL.Decode exposing
    ( Decoder
    , test
    , string, float, int, bool, id
    , scalar
    , enum
    , object, field
    , maybe, list
    , union, interface
    , Variant, variant
    , map
    , toJsonDecoder
    )

{-|

@docs Decoder


## **Learning and troubleshooting**

When I first got started with JSON decoders, I had a hard time visualizing what was going on.
For that reason, this module comes with a [`test`](#test) function to help you
easily verify your code is behaving the way you expect.

This is inspired by the `elm/json` package's [`decodeString`](https://package.elm-lang.org/packages/elm/json/latest/Json-Decode#decodeString)
function, which is great for testing JSON decoders when you get stuck!

@docs test


## **Scalars**

In GraphQL, [scalars](https://graphql.org/learn/schema/#scalar-types) are strings, numbers,
IDs, and other basic primitives that your API can send. For the five built-in scalars, these functions are provided below.

See the [`scalar`](#scalar) function to work with custom scalars specific to your API.

@docs string, float, int, bool, id
@docs scalar


## **Enums**

@docs enum


## **Objects**

@docs object, field


### **Lists & Nullable Fields**

@docs maybe, list


## **Interfaces & Union Types**


### **❗️ Always include \_\_typename**

Interfaces and union type decoders require the `__typename` field in the selection. Without it,
Elm won't be able to match on the typename provided.

Here's an example from the official GraphQL documentation:

```graphql
{
  search(text: "an") {
    __typename
    ... on Human {
      name
      height
    }
    ... on Droid {
      name
      primaryFunction
    }
    ... on Starship {
      name
      length
    }
  }
}
```

Because the `hero` query returns an `interface`, you should always include `__typename` in your selection set.
This will allow your Elm frontend to know which types came back:

```json
{
  "data": {
    "search": [
      {
        "__typename": "Human",
        "name": "Han Solo",
        "height": 1.8
      },
      {
        "__typename": "Human",
        "name": "Leia Organa",
        "height": 1.5
      },
      {
        "__typename": "Starship",
        "name": "TIE Advanced x1",
        "length": 9.2
      }
    ]
  }
}
```

@docs union, interface
@docs Variant, variant


## **Internals**

These functions are used internally by GraphQL.Http, and you won't need them in your projects.

@docs map
@docs toJsonDecoder

-}

import GraphQL.Scalar.Id exposing (Id)
import Json.Decode


{-| When you make a GraphQL request, you'll get a JSON response like this one:

```json
{
  "data": {
    "hero": {
      "name": "R2-D2",
      "appearsIn": [
        "NEWHOPE",
        "EMPIRE",
        "JEDI"
      ]
    }
  }
}
```

This `Decoder` type represents a value that knows how to convert a raw JSON response into standard Elm values that can be used in your Elm application.

-}
type Decoder value
    = Decoder
        { decoder : Json.Decode.Decoder value
        }


{-| Map a decoder of one value to another.
-}
map : (a -> b) -> Decoder a -> Decoder b
map fn (Decoder { decoder }) =
    Decoder { decoder = Json.Decode.map fn decoder }


{-| -}
toJsonDecoder : Decoder value -> Json.Decode.Decoder value
toJsonDecoder (Decoder { decoder }) =
    decoder



-- SCALAR TYPES


{-| A decoder for the built-in `String` scalar.

    import GraphQL.Decode

    GraphQL.Decode.test
        { decoder = GraphQL.Decode.string
        , json = """ "Hello, world!" """
        }
        == Ok "Hello, world!"

-}
string : Decoder String
string =
    scalar Json.Decode.string


{-| A decoder for the built-in `Float` scalar.

    import GraphQL.Decode

    GraphQL.Decode.test
        { decoder = GraphQL.Decode.float
        , json = """ 1.25 """
        }
        == Ok 1.25

-}
float : Decoder Float
float =
    scalar Json.Decode.float


{-| A decoder for the built-in `Int` scalar.

    import GraphQL.Decode

    GraphQL.Decode.test
        { decoder = GraphQL.Decode.int
        , json = """ 9000 """
        }
        == Ok 9000

-}
int : Decoder Int
int =
    scalar Json.Decode.int


{-| A decoder for the built-in `Boolean` scalar.

    import GraphQL.Decode

    GraphQL.Decode.test
        { decoder = GraphQL.Decode.bool
        , json = """ true """
        }
        == Ok True

-}
bool : Decoder Bool
bool =
    scalar Json.Decode.bool


{-| A decoder for the built-in `ID` scalar.

Uses [GraphQL.Scalar.Id](./GraphQL-Scalar-Id) as a way to prevent
mixing up `String` and `Id` values.

    import GraphQL.Decode

    -- Works with JSON strings
    GraphQL.Decode.test
        { decoder = GraphQL.Decode.id
        , json = """ "abc" """
        }
        == Ok (Id "abc")

    -- Works with JSON numbers
    test
        { decoder = id
        , json = """ 12345 """
        }
        == Ok (Id "12345")

-}
id : Decoder Id
id =
    scalar
        (Json.Decode.oneOf
            [ Json.Decode.string
                |> Json.Decode.map GraphQL.Scalar.Id.fromString
            , Json.Decode.int
                |> Json.Decode.map GraphQL.Scalar.Id.fromInt
            ]
        )


{-| GraphQL allows APIs to define custom scalar values, like `Date` or `Currency`. This function
allows you to work with those custom values.

Here's an example of using this function to work with a `DateTime` type. We recommend defining each custom scalar
in a separate Elm module, like `GraphQL.Scalar.DateTime`:

    -- module GraphQL.Scalar.DateTime exposing
    --     ( DateTime
    --     , decoder, encode
    --     )


    import GraphQL.Decode exposing (Decoder)
    import Iso8601
    import Time

    type alias DateTime =
        Time.Posix

    decoder : Decoder DateTime
    decoder =
        GraphQL.Decode.scalar Iso8601.decoder

The snippet above uses [`elm/time`](https://package.elm-lang.org/packages/elm/time) and [`rtfeldman/elm-iso8601-date-strings`](https://package.elm-lang.org/packages/rtfeldman/elm-iso8601-date-strings/latest/Iso8601)
to convert a `String` value from our API into a `Time.Posix` value.

    import GraphQL.Decode
    import GraphQL.Scalar.DateTime

    GraphQL.Decode.test
        { decoder = GraphQL.Scalar.DateTime.decoder
        , value = """ "2022-12-26T01:45:56.520Z" """
        }
        == Ok (Posix 1672019156520)

-}
scalar : Json.Decode.Decoder scalar -> Decoder scalar
scalar jsonDecoder =
    Decoder { decoder = jsonDecoder }



-- ENUMERATION TYPES


{-| A decoder for handling [enum values](https://graphql.org/learn/schema/#enumeration-types). It allows you to specify a list of allowed enums that can
come back with a certain request.

To prevent code duplication, we recommend defining one `decoder` for each enum in a separate Elm module,
like `GraphQL.Enum.Episode`. Here's how you can use this function to define a decoder for
the `Episode` enum type:

    import GraphQL.Decode exposing (Decoder)

    type Episode
        = NewHope
        | EmpireStrikesBack
        | ReturnOfTheJedi

    decoder : Decoder Episode
    decoder =
        GraphQL.Decode.enum
            [ ( "NEWHOPE", NewHope )
            , ( "EMPIRE", EmpireStrikesBack )
            , ( "RETURN", ReturnOfTheJedi )
            ]

**Note:** If an enum is missing from that list, this package will return a
JSON decoding error letting you know which enum variant was missing.

-}
enum : List ( String, enum ) -> Decoder enum
enum lookup =
    let
        toEnum : String -> Json.Decode.Decoder enum
        toEnum str =
            case List.filter (\( key, _ ) -> key == str) lookup of
                [] ->
                    Json.Decode.fail ("Unexpected enum value: " ++ str)

                ( _, value ) :: _ ->
                    Json.Decode.succeed value
    in
    Decoder
        { decoder =
            Json.Decode.string
                |> Json.Decode.andThen toEnum
        }



-- OBJECT TYPES


{-| A decoder for working with [object types](https://graphql.org/learn/schema/#object-types-and-fields).
This function works in conjunction with [`field`](#field) to allow you to safely decode one field at a time.

    import GraphQL.Decode exposing (Decoder)

    type alias Person =
        { id : Id
        , fullName : String
        }

    decoder : Decoder Person
    decoder =
        GraphQL.Decode.object Person
            |> GraphQL.Decode.field
                { name = "id"
                , decoder = GraphQL.Decode.id
                }
            |> GraphQL.Decode.field
                { name = "fullName"
                , decoder = GraphQL.Decode.string
                }

-}
object : (field -> object) -> Decoder (field -> object)
object fn =
    Decoder { decoder = Json.Decode.succeed fn }


{-| When used with [`object`](#object), this function allows you to
add fields to an object.

**Note:** The order of the fields in the `type alias` need to match
the order you add the fields in your decoder.

    import GraphQL.Decode exposing (Decoder)
    import GraphQL.Enum.Episode

    type alias Jedi =
        { name : String
        , appearsIn : List GraphQL.Enum.Episode
        }

    decoder : Decoder Person
    decoder =
        GraphQL.Decode.object Person
            |> GraphQL.Decode.field
                { name = "name"
                , decoder = GraphQL.Decode.string
                }
            |> GraphQL.Decode.field
                { name = "appearsIn"
                , decoder =
                    GraphQL.Decode.list
                        GraphQL.Enum.Episode.decoder
                }

-}
field :
    { name : String
    , decoder : Decoder field
    }
    -> Decoder (field -> output)
    -> Decoder output
field options (Decoder fn) =
    let
        (Decoder selection) =
            options.decoder

        (Decoder value) =
            Decoder
                { decoder = Json.Decode.field options.name selection.decoder
                }
    in
    Decoder
        { decoder =
            Json.Decode.map2 (|>)
                value.decoder
                fn.decoder
        }


{-| Use this function to tell an existing decoder that we expect a nullable value,
which might not guaranteed to be available:

    import GraphQL.Decode exposing (Decoder)

    stringDecoder : Decoder String
    stringDecoder =
        GraphQL.Decoder.string

    nullableStringDecoder : Decoder (Maybe String)
    nullableStringDecoder =
        GraphQL.Decoder.maybe GraphQL.Decoder.string

-}
maybe : Decoder value -> Decoder (Maybe value)
maybe (Decoder value) =
    Decoder { decoder = Json.Decode.maybe value.decoder }


{-| Use this function to tell an existing decoder that we expect a list of values,
rather than a single value:

    import GraphQL.Decode exposing (Decoder)

    stringDecoder : Decoder String
    stringDecoder =
        GraphQL.Decoder.string

    listOfStringDecoder : Decoder (List String)
    listOfStringDecoder =
        GraphQL.Decoder.list GraphQL.Decoder.string

-}
list : Decoder value -> Decoder (List value)
list (Decoder value) =
    Decoder { decoder = Json.Decode.list value.decoder }



-- INTERFACES & UNION TYPES


{-| Decoder for [interfaces](https://graphql.org/learn/schema/#interfaces) that allow you to select extra fields. This works alongside the [`variant`](#variant)
function to define which variants you are interested in tracking.

    import GraphQL.Decode exposing (Decoder)

    type HeroInterface
        = On_Human Human
        | On_Droid Droid

    decoder : Decoder SearchUnion
    decoder =
        GraphQL.Decode.interface
            [ GraphQL.Decode.variant
                { typename = "Human"
                , onVariant = On_Human
                , decoder = humanDecoder
                }
            , GraphQL.Decode.variant
                { typename = "Droid"
                , onVariant = On_Droid
                , decoder = droidDecoder
                }
            ]

You can see the [`union`](#union) example to understand how to
make `humanDecoder` or `droidDecoder`. Their implementations are identical!

❗️ [See the important note about using `__typename`](#-always-include-_-_typename-) to prevent issues

-}
interface : List (Variant interface) -> Decoder interface
interface =
    union


{-| Decoder for a [union type](https://graphql.org/learn/schema/#union-types). Use this with the [`variant`](#variant) function to select variants by typename:

    import GraphQL.Decode exposing (Decoder)

    type SearchUnion
        = On_Human Human
        | On_Droid Droid
        | On_Starship Starship

    decoder : Decoder SearchUnion
    decoder =
        GraphQL.Decode.union
            [ GraphQL.Decode.variant
                { typename = "Human"
                , onVariant = On_Human
                , decoder = humanDecoder
                }
            , GraphQL.Decode.variant
                { typename = "Droid"
                , onVariant = On_Droid
                , decoder = droidDecoder
                }
            , GraphQL.Decode.variant
                { typename = "Starship"
                , onVariant = On_Starship
                , decoder = starshipDecoder
                }
            ]

Each variant will expect a decoder for the data you expect. This will involve using
the [`object`](#object) and [`field`](#field) functions in this module:

    type alias Human =
        { name : String
        , height : Int
        }

    humanDecoder : Decoder Human
    humanDecoder =
        GraphQL.Decode.object Human
            |> GraphQL.Decode.field
                { name = "name"
                , decoder = GraphQL.Decode.string
                }
            |> GraphQL.Decode.field
                { name = "height"
                , decoder = GraphQL.Decode.int
                }

    type alias Droid =
        { name : String
        , primaryFunction : String
        }

    droidDecoder : Decoder Droid
    droidDecoder =
        GraphQL.Decode.object Droid
            |> GraphQL.Decode.field
                { name = "name"
                , decoder = GraphQL.Decode.string
                }
            |> GraphQL.Decode.field
                { name = "primaryFunction"
                , decoder = GraphQL.Decode.string
                }

    type alias Starship =
        { name : String
        , length : Int
        }

    starshipDecoder : Decoder Starship
    starshipDecoder =
        GraphQL.Decode.object Starship
            |> GraphQL.Decode.field
                { name = "name"
                , decoder = GraphQL.Decode.string
                }
            |> GraphQL.Decode.field
                { name = "length"
                , decoder = GraphQL.Decode.int
                }

❗️ [See the important note about using `__typename`](#-always-include-_-_typename-) to prevent issues

-}
union : List (Variant union) -> Decoder union
union variants =
    let
        jsonDecoders : List (Json.Decode.Decoder union)
        jsonDecoders =
            variants
                |> List.map (\(Variant (Decoder json)) -> json.decoder)
    in
    Decoder
        { decoder = Json.Decode.oneOf jsonDecoders
        }


{-| A type that represents a custom type variant on a union type or interface. These are used with
[`union`](#union) or [`interface`](#interface) in the examples above.
-}
type Variant value
    = Variant (Decoder value)


{-| A function intended to be used with [`union`](#union) or [`interface`](#interface) for
selecting specific custom type variants by typename.

    import GraphQL.Decode exposing (Variant)

    type HeroInterface
        = On_Human Human
        | On_Droid Droid

    humanVariant : Variant HeroInterface
    humanVariant =
        GraphQL.Decode.variant
            { typename = "Human"
            , onVariant = On_Human
            , decoder = humanDecoder
            }

    droidVariant : Variant HeroInterface
    droidVariant =
        GraphQL.Decode.variant
            { typename = "Droid"
            , onVariant = On_Droid
            , decoder = droidDecoder
            }

-}
variant :
    { typename : String
    , onVariant : object -> value
    , decoder : Decoder object
    }
    -> Variant value
variant options =
    let
        (Decoder a) =
            options.decoder
    in
    Variant
        (Decoder
            { decoder =
                Json.Decode.field "__typename" Json.Decode.string
                    |> Json.Decode.andThen
                        (\typename ->
                            if typename == options.typename then
                                Json.Decode.map options.onVariant a.decoder

                            else
                                Json.Decode.fail ("Did not match __typename: " ++ options.typename)
                        )
            }
        )


{-| This function is exposed so you can quickly check if your GraphQL `Decoder` works as you expect
with a raw JSON string.

    import GraphQL.Decode

    testResult : Result Http.Error Int
    testResult =
        GraphQL.Decode.test
            { decoder = GraphQL.Decode.int
            , json = """ 1000 """"
            }

-}
test :
    { decoder : Decoder value
    , json : String
    }
    -> Result Json.Decode.Error value
test options =
    Json.Decode.decodeString
        (toJsonDecoder options.decoder)
        options.json
