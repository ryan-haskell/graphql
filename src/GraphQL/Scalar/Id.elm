module GraphQL.Scalar.Id exposing
    ( Id
    , fromString, fromInt
    , toString
    )

{-|


## **Custom scalars**

Using the [`GraphQL.Decode.scalar`](./GraphQL-Decode#scalar) and [`GraphQL.Encode.scalar`](./GraphQL-Encode#scalar) functions, you can define
Elm modules like this one in your own codebase for any custom scalars you need.

Because the `ID` scalar is built-in to the GraphQL specification, we provide this one for
you by default. Your custom scalars will also include a `decoder` / `encode` function so they
are easy to reuse across your application!

@docs Id
@docs fromString, fromInt
@docs toString

-}


{-| Represents a GraphQL `ID` scalar value.
-}
type Id
    = Id String


{-| Use a `String` value to create a new `ID`:

    import GraphQL.Scalar.Id exposing (Id)

    id : Id
    id =
        GraphQL.Scalar.Id.fromString "12a4bf"

-}
fromString : String -> Id
fromString string =
    Id string


{-| Use a `Int` value to create a new `ID`:

    import GraphQL.Scalar.Id exposing (Id)

    id : Id
    id =
        GraphQL.Scalar.Id.fromInt 123

-}
fromInt : Int -> Id
fromInt int =
    Id (String.fromInt int)


{-| Convert an existing `ID` to a `String` value:

    import GraphQL.Scalar.Id exposing (Id)

    messageToUser : String
    messageToUser =
        "Your ID is: " ++ GraphQL.Scalar.Id.toString userId

-}
toString : Id -> String
toString (Id string) =
    string
