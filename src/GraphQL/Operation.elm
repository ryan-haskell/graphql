module GraphQL.Operation exposing
    ( Operation, new
    , map
    , toHttpCmd
    , toHttpCmdWithPartialErrors
    )

{-| In GraphQL, an "operation" represents a query or mutation.

( If you're just getting started to this package, I'd ignore this and try `GraphQL.Http` instead! )

This module exposes functions to make it easier to set up error reporting for
all GraphQL requests in one place. Rather than executing `Cmd` values directly
from the `GraphQL.Http` package, you can describe your GraphQL operations as data, and
handle the actual HTTP stuff in one place.

This makes it easier to work with user tokens, environment specific URLs, without needing to
pass that context through for each page that uses GraphQL.

@docs Operation, new
@docs map
@docs toHttpCmd


## **Partial errors**

@docs toHttpCmdWithPartialErrors

-}

import GraphQL.Decode
import GraphQL.Encode
import GraphQL.Error
import GraphQL.Http
import Http
import Json.Decode


{-| An operation represents a GraphQL query or mutation.
-}
type Operation data
    = Operation
        { name : String
        , query : String
        , variables : List ( String, GraphQL.Encode.Value )
        , decoder : GraphQL.Decode.Decoder data
        }


{-| Create a new operation:

    operation : Operation Data
    operation =
        GraphQL.Operation.new
            { name = "FetchRepos"
            , query = """
                query FetchRepos($first: Int!) {
                  repos(first: $first) {
                    id
                    name
                    owner
                  }
                }
            """
            , variables =
                [ ( "first", GraphQL.Encode.int 25 )
                ]
            , decoder =
                GraphQL.Decode.object Data
                    |> GraphQL.Decode.field
                        { name = "repos"
                        , decoder = ...
                        }
            }

-}
new :
    { name : String
    , query : String
    , variables : List ( String, GraphQL.Encode.Value )
    , decoder : GraphQL.Decode.Decoder data
    }
    -> Operation data
new options =
    Operation options



-- MAP


{-| Convert an operation from one type variable to another. This is especially useful when using the `Effect msg` type in
an [Elm Land](https://elm.land) application. (Although the effect pattern can be used without the Elm Land framework!)

The `map` function allows us to eliminate that extra `data` type variable, so we can still use `Effect msg` as expected:

    type Effect msg
        = -- ...
        | SendGraphQL
            { operation : GraphQL.Operation.Operation msg
            , onError : GraphQL.Http.Error -> msg
            }

    sendGraphQL :
        { operation : Operation data
        , onResponse : Result GraphQL.Http.Error data -> msg
        }
        -> Effect msg
    sendGraphQL props =
        let
            operation : Operation msg
            operation =
                GraphQL.Operation.map
                    (\data -> props.onResponse (Ok data))
                    props.operation
        in
        SendGraphQL
            { operation = operation
            , onError = \httpError -> props.onResponse (Err httpError)
            }

-}
map : (a -> b) -> Operation a -> Operation b
map fn (Operation operation) =
    Operation
        { name = operation.name
        , query = operation.query
        , variables = operation.variables
        , decoder = GraphQL.Decode.map fn operation.decoder
        }



-- CMD


{-| Send an HTTP request with the GraphQL operation. Below is an example of how you
can use it with [Elm Land's](https://elm.land) `Effect` module to ensure all
GraphQL HTTP errors are reported automatically:

    type Effect msg
        = -- ...
        | SendGraphQL
            { operation : GraphQL.Operation.Operation msg
            , onError : GraphQL.Http.Error -> msg
            }

    toCmd :
        { options
            | effect : Effect msg
            , fromSharedMsg : Shared.Msg -> msg
            , batch : List msg -> msg
        }
        -> Cmd msg
    toCmd options =
        case options.effect of

            -- ...

            SendGraphQL { operation, onError } ->
                GraphQL.Operation.toHttpCmd
                    { method = "POST"
                    , url = "https://api.github.com/graphql"
                    , headers =
                        [ Http.header "Authorization" "Bearer {...}"
                        ]
                    , timeout = Just 30000
                    , tracker = Nothing
                    , operation = operation
                    , onResponse =
                        \result ->
                            case result of
                                Ok msg ->
                                    msg

                                Err httpError ->
                                    options.batch
                                        [ onError httpError
                                        , Shared.Msg.ReportHttpError httpError
                                            |> options.fromSharedMsg
                                        ]
                    }

-}
toHttpCmd :
    { method : String
    , url : String
    , headers : List Http.Header
    , timeout : Maybe Float
    , tracker : Maybe String
    , operation : Operation data
    , onResponse : Result GraphQL.Http.Error data -> msg
    }
    -> Cmd msg
toHttpCmd options =
    let
        (Operation operation) =
            options.operation
    in
    Http.request
        { method = options.method
        , url = options.url
        , headers = options.headers
        , body =
            GraphQL.Http.body
                { operationName = Just operation.name
                , query = operation.query
                , variables = operation.variables
                }
        , expect =
            GraphQL.Http.expect
                options.onResponse
                operation.decoder
        , timeout = options.timeout
        , tracker = options.tracker
        }



-- CMD


{-| This is the same as `toHttpCmd`, but changes the type of `onResponse` to support [partial errors](./GraphQL-Error#-partial-errors-)
with successful GraphQL responses.

    type Effect msg
        = -- ...
        | SendGraphQL
            { operation : GraphQL.Operation.Operation msg
            , onError : Http.Error -> msg
            }

-}
toHttpCmdWithPartialErrors :
    { method : String
    , url : String
    , headers : List Http.Header
    , timeout : Maybe Float
    , tracker : Maybe String
    , operation : Operation data
    , onResponse :
        Result
            GraphQL.Http.Error
            { data : data
            , errors : List GraphQL.Error.Error
            }
        -> msg
    }
    -> Cmd msg
toHttpCmdWithPartialErrors options =
    let
        (Operation operation) =
            options.operation
    in
    Http.request
        { method = options.method
        , url = options.url
        , headers = options.headers
        , body =
            GraphQL.Http.body
                { operationName = Just operation.name
                , query = operation.query
                , variables = operation.variables
                }
        , expect =
            GraphQL.Http.expectWithPartialErrors
                options.onResponse
                operation.decoder
        , timeout = options.timeout
        , tracker = options.tracker
        }
