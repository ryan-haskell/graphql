module GraphQL.Value exposing
    ( Value
    , fromJson, toJson
    )

{-|

@docs Value
@docs fromJson, toJson

-}
import Json.Encode


type Value
    = Value Json.Encode.Value


fromJson : Json.Encode.Value -> Value
fromJson json =
    Value json


toJson : Value -> Json.Encode.Value
toJson (Value json) =
    json