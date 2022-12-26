module GraphQL.Scalar.Id exposing
    ( Id
    , fromString, fromInt
    , toString
    )

{-|

@docs Id
@docs fromString, fromInt
@docs toString

-}


{-| -}
type Id
    = Id String


{-| -}
fromString : String -> Id
fromString string =
    Id string


{-| -}
fromInt : Int -> Id
fromInt int =
    Id (String.fromInt int)


{-| -}
toString : Id -> String
toString (Id string) =
    string
