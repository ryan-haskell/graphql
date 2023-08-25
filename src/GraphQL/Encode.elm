module GraphQL.Encode exposing
    ( Value
    , string, float, int, bool, id
    , scalar
    , enum
    , input
    , list, maybe, null
    , toJson
    )

{-|

@docs Value


## **Scalars**

@docs string, float, int, bool, id
@docs scalar


## **Enums**

@docs enum


## **Input types**

@docs input


## **Advanced**

@docs list, maybe, null


## **Internals**

These functions are used internally by [`GraphQL.Http`](./GraphQL-Http), and you won't need them in your projects

@docs toJson

-}

import GraphQL.Scalar.Id exposing (Id)
import Json.Encode


{-| The `Value` type represents a JSON value that will be sent to your GraphQL API.
When you use this with the [`GraphQL.Http`](./GraphQL-Http) module, this is an example
of what will be sent with your HTTP request:

```json
{
    "variables": {
        "id": "123",
        "form": {
            "email": "ryan@elm.land",
            "password": "secret123"
        }
    }
}
```

-}
type Value
    = Value Json.Encode.Value


{-| -}
fromJson : Json.Encode.Value -> Value
fromJson json =
    Value json


{-| -}
toJson : Value -> Json.Encode.Value
toJson (Value json) =
    json



-- SCALAR TYPES


{-| Create a GraphQL input from a `String` value:

    import GraphQL.Encode

    name : GraphQL.Encode.Value
    name =
        GraphQL.Encode.string "Ryan"

-}
string : String -> Value
string value =
    value
        |> Json.Encode.string
        |> Value


{-| Create a GraphQL input from a `Float` value:

    import GraphQL.Encode

    score : GraphQL.Encode.Value
    score =
        GraphQL.Encode.float 0.99

-}
float : Float -> Value
float value =
    value
        |> Json.Encode.float
        |> Value


{-| Create a GraphQL input from a `Int` value:

    import GraphQL.Encode

    age : GraphQL.Encode.Value
    age =
        GraphQL.Encode.int 62

-}
int : Int -> Value
int value =
    value
        |> Json.Encode.int
        |> Value


{-| Create a GraphQL input from a `Bool` value:

    import GraphQL.Encode

    isReadingThis : GraphQL.Encode.Value
    isReadingThis =
        GraphQL.Encode.bool True

-}
bool : Bool -> Value
bool value =
    value
        |> Json.Encode.bool
        |> Value


{-| Create a GraphQL input from a `Id` value:

    import GraphQL.Encode
    import GraphQL.Scalar.Id exposing (Id)

    userId : Id
    userId =
        GraphQL.Scalar.Id.fromInt 1203

    isReadingThis : GraphQL.Encode.Value
    isReadingThis =
        GraphQL.Encode.id userId

-}
id : Id -> Value
id value =
    value
        |> GraphQL.Scalar.Id.toString
        |> Json.Encode.string
        |> Value


{-| Here's an example of using this function to work with a `DateTime` type. We recommend defining each custom scalar
in a separate Elm module, like `GraphQL.Scalar.DateTime`:

    -- module GraphQL.Scalar.DateTime exposing
    --     ( DateTime
    --     , decoder, encode
    --     )


    import GraphQL.Encode
    import Iso8601
    import Time

    type alias DateTime =
        Time.Posix

    encode : DateTime -> GraphQL.Encode.Value
    encode dateTime =
        GraphQL.Encode.scalar
            { toJson = Iso8601.encode
            , value = dateTime
            }

The snippet above uses [`elm/time`](https://package.elm-lang.org/packages/elm/time) and [`rtfeldman/elm-iso8601-date-strings`](https://package.elm-lang.org/packages/rtfeldman/elm-iso8601-date-strings/latest/Iso8601)
to convert our `Time.Posix` value into an ISO 8601 `String` value for our API.

    import GraphQL.Scalar.DateTime

    GraphQL.Scalar.DateTime.encode
        (Time.millisToPosix 1672019156520)
        == Json "2022-12-26T01:45:56.520Z"

-}
scalar :
    { toJson : scalar -> Json.Encode.Value
    , value : scalar
    }
    -> Value
scalar options =
    options.value
        |> options.toJson
        |> Value



-- ENUMERATION TYPES


{-| Create a GraphQL input from an enum value. To avoid duplicating code, we recommend
you create a separate Elm module per enum, like `GraphQL.Enum.Episode`.

In that module, you can define your `encode` function in one place:

    -- module GraphQL.Enum.Episode exposing
    --     ( Episode(..), list
    --     , decoder, encode
    --     )


    import GraphQL.Encode

    type Episode
        = NewHope
        | EmpireStrikesBack
        | ReturnOfTheJedi

    encode : Episode -> GraphQL.Encode.Value
    encode episode =
        GraphQL.Encode.enum
            { toString = toString
            , value = episode
            }

    toString : Episode -> String
    toString episode =
        case episode of
            NewHope ->
                "NEWHOPE"

            EmpireStrikesBack ->
                "EMPIRE"

            ReturnOfTheJedi ->
                "RETURN"

-}
enum :
    { toString : enum -> String
    , value : enum
    }
    -> Value
enum options =
    options.value
        |> options.toString
        |> Json.Encode.string
        |> Value



-- INPUT TYPES


{-| GraphQL allows the API to define [input types](https://graphql.org/learn/schema/#input-types). These allow you to group
your inputs into an object, like this:

    import GraphQL.Encode

    reviewInputValue : GraphQL.Encode.Value
    reviewInputValue =
        GraphQL.Encode.input
            [ ( "stars"
              , GraphQL.Encode.int 10
              )
            , ( "commentary"
              , GraphQL.Encode.int "Would eat again!"
              )
            ]

-}
input : List ( String, Value ) -> Value
input fields =
    let
        toJsonField : ( String, Value ) -> ( String, Json.Encode.Value )
        toJsonField ( key, value ) =
            ( key
            , toJson value
            )
    in
    Json.Encode.object
        (List.map toJsonField fields)
        |> Value


{-| Send a `null` value to a GraphQL API. This is commonly used by mutations
to mark a field as removed.

    import GraphQL.Encode

    profileInputValue : GraphQL.Encode.Value
    profileInputValue =
        GraphQL.Encode.input
            [ ( "name"
              , GraphQL.Encode.string "Ryan"
              )
            , ( "bio"
              , GraphQL.Encode.null
              )
            ]

-}
null : Value
null =
    Value Json.Encode.null


{-| Create a `Maybe` value, using `null` if there is no value provided:

    import GraphQL.Encode

    encodeEmail : Maybe String -> GraphQL.Encode.Value
    encodeEmail email =
        GraphQL.Encode.maybe GraphQL.Encode.string email


    encodeEmail Nothing == """ null """
    encodeEmail (Just "ryan@elm.land") == """ "ryan@elm.land" """

-}
maybe : (a -> Value) -> Maybe a -> Value
maybe toValue maybe_ =
    case maybe_ of
        Nothing ->
            null

        Just a ->
            toValue a


{-| Create a value from a list:

    import GraphQL.Encode

    encodeIds : List Int -> GraphQL.Encode.Value
    encodeIds ids =
        GraphQL.Encode.list GraphQL.Encode.int ids


    encodeIds [] == """ [] """
    encodeIds [1,2,3] == """ [1,2,3] """

-}
list : (a -> Value) -> List a -> Value
list toValue list_ =
    Value
        (Json.Encode.list
            (toValue >> (\(Value x) -> x))
            list_
        )
