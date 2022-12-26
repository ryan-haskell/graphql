module GraphQL.Internals.Decoder exposing (Decoder(..), toJsonDecoder)

import Json.Decode


type Decoder value
    = Decoder
        { decoder : Json.Decode.Decoder value
        }


{-| -}
toJsonDecoder : Decoder value -> Json.Decode.Decoder value
toJsonDecoder (Decoder { decoder }) =
    decoder
