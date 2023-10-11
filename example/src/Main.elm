module Main exposing (main)

import Browser
import GraphQL.Decode
import GraphQL.Encode
import GraphQL.Http
import GraphQL.Scalar.Id exposing (Id)
import Html exposing (Html)
import Html.Attributes exposing (alt, src, style)


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }



-- INIT


type alias Model =
    { pokemon : Response Data
    }


type Response value
    = Loading
    | Success value
    | Failure GraphQL.Http.Error


init : () -> ( Model, Cmd Msg )
init _ =
    ( { pokemon = Loading }
    , fetchPokemon { limit = 150 }
    )


fetchPokemon : { limit : Int } -> Cmd Msg
fetchPokemon input =
    GraphQL.Http.post
        { url = "https://beta.pokeapi.co/graphql/v1beta"
        , query = """
            query FetchPokemon($limit: Int!) {
              pokemon_v2_pokemon(limit: $limit) {
                name
                id
              }
            }
          """
        , variables =
            [ ( "limit"
              , GraphQL.Encode.int input.limit
              )
            ]
        , onResponse = ApiResponded
        , decoder = decoder
        }



-- UPDATE


type Msg
    = ApiResponded (Result GraphQL.Http.Error Data)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ApiResponded (Ok data) ->
            ( { model | pokemon = Success data }
            , Cmd.none
            )

        ApiResponded (Err httpError) ->
            ( { model | pokemon = Failure httpError }
            , Cmd.none
            )



-- DATA


type alias Data =
    { pokemon : List Pokemon
    }


decoder : GraphQL.Decode.Decoder Data
decoder =
    GraphQL.Decode.object Data
        |> GraphQL.Decode.field
            { name = "pokemon_v2_pokemon"
            , decoder = GraphQL.Decode.list pokemonDecoder
            }


type alias Pokemon =
    { id : Int
    , name : String
    }


pokemonDecoder : GraphQL.Decode.Decoder Pokemon
pokemonDecoder =
    GraphQL.Decode.object Pokemon
        |> GraphQL.Decode.field
            { name = "id"
            , decoder = GraphQL.Decode.int
            }
        |> GraphQL.Decode.field
            { name = "name"
            , decoder = GraphQL.Decode.string
            }



-- VIEW


view : Model -> Html Msg
view model =
    case model.pokemon of
        Loading ->
            Html.text "Loading..."

        Success data ->
            Html.div
                [ style "margin" "2rem"
                , style "font-family" "sans-serif"
                ]
                (List.map viewPokemon data.pokemon)

        Failure httpError ->
            Html.pre []
                [ Html.code []
                    [ Html.text (fromErrorToString httpError) ]
                ]


viewPokemon : Pokemon -> Html msg
viewPokemon pokemon =
    let
        spriteUrl =
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/"
                ++ String.fromInt pokemon.id
                ++ ".png"
    in
    Html.div
        [ style "display" "flex"
        , style "align-items" "center"
        , style "gap" "1rem"
        , style "font-size" "2rem"
        ]
        [ Html.img
            [ style "width" "5rem"
            , style "height" "5rem"
            , alt pokemon.name
            , src spriteUrl
            ]
            []
        , Html.strong [] [ Html.text pokemon.name ]
        ]


fromErrorToString : GraphQL.Http.Error -> String
fromErrorToString error =
    case error of
        GraphQL.Http.GraphQL { errors } ->
            errors
                |> List.map .message
                |> String.join "\n"

        GraphQL.Http.BadUrl _ ->
            "Unexpected API URL"

        GraphQL.Http.Timeout ->
            "API request timed out"

        GraphQL.Http.NetworkError ->
            "Couldn't connect to API"

        GraphQL.Http.UnexpectedResponse { statusCode } ->
            if statusCode >= 400 then
                "Bad status code"

            else
                "Unexpected response from API"



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
