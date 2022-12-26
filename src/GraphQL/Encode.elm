module GraphQL.Encode exposing
    ( Value
    , string, float, int, boolean, id
    , scalar
    , enum
    , input
    )

{-|

@docs Value


## **Scalars**

@docs string, float, int, boolean, id
@docs scalar


## **Enums**

@docs enum


## **Input types**

@docs input

-}

import GraphQL.Scalar.Id exposing (Id)
import GraphQL.Value
import Json.Encode


{-| The `Value` type represents a JSON value that can be sent to your GraphQL API as a variable.
-}
type alias Value =
    GraphQL.Value.Value


{-| -}
id : Id -> Value
id value =
    value
        |> GraphQL.Scalar.Id.toString
        |> Json.Encode.string
        |> GraphQL.Value.fromJson


{-| -}
string : String -> Value
string value =
    value
        |> Json.Encode.string
        |> GraphQL.Value.fromJson


{-| -}
float : Float -> Value
float value =
    value
        |> Json.Encode.float
        |> GraphQL.Value.fromJson


{-| -}
int : Int -> Value
int value =
    value
        |> Json.Encode.int
        |> GraphQL.Value.fromJson


{-| -}
boolean : Bool -> Value
boolean value =
    value
        |> Json.Encode.bool
        |> GraphQL.Value.fromJson


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
        |> GraphQL.Value.fromJson


{-| -}
enum :
    { toString : enum -> String
    , value : enum
    }
    -> Value
enum options =
    options.value
        |> options.toString
        |> Json.Encode.string
        |> GraphQL.Value.fromJson


{-| -}
input : List ( String, Value ) -> Value
input fields =
    let
        toJsonField : ( String, Value ) -> ( String, Json.Encode.Value )
        toJsonField ( key, value ) =
            ( key
            , GraphQL.Value.toJson value
            )
    in
    Json.Encode.object
        (List.map toJsonField fields)
        |> GraphQL.Value.fromJson
