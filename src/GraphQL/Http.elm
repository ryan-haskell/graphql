module GraphQL.Http exposing
    ( get, post
    , body, expect
    )

{-|


## **Making HTTP requests**

@docs get, post


## **Advanced usage with `elm/http`**

The two functions below are helpful for more advanced applications using functions like [`Http.request`](https://package.elm-lang.org/packages/elm/http/latest/Http#request).

Use these if you need to send HTTP headers, define request timeouts, etc.

    import GraphQL.Http
    import Http

    fetchCurrentUser : Cmd Msg
    fetchCurrentUser =
        Http.request
            { method = "POST"
            , url = "/api/graphql"
            , headers = []
            , body =
                GraphQL.Http.body
                    { operationName = Just "FetchCurrentUser"
                    , query = """
                        query FetchCurrentUser {
                            me {
                                id
                                name
                            }
                        }
                    """
                    , variables = []
                    }
            , expect =
                GraphQL.Http.expect
                    FetchCurrentUserApiResponded
                    decoder
            , tracker = Nothing
            , timeout = Nothing
            }

@docs body, expect

-}

import GraphQL.Decode
import GraphQL.Encode
import GraphQL.Internals.Decoder
import GraphQL.Value
import Http
import Json.Decode
import Json.Encode


{-| Send an HTTP `GET` request to your GraphQL API

    GraphQL.Http.get
        { url = "/api/graphql"
        , query = """
            query FindPerson(name: $name) {
                person(name: $name) {
                    id
                    name
                }
            }
        """
        , variables =
            [ ( "name", GraphQL.Encode.string "Doug" )
            ]
        , onResponse = ApiResponded
        , decoder = decoder
        }

-}
get :
    { url : String
    , query : String
    , variables : List ( String, GraphQL.Encode.Value )
    , decoder : GraphQL.Decode.Decoder data
    , onResponse : Result Http.Error data -> msg
    }
    -> Cmd msg
get options =
    Http.request
        { method = "GET"
        , headers = []
        , url = options.url
        , body =
            body
                { operationName = Nothing
                , query = options.query
                , variables = options.variables
                }
        , expect = expect options.onResponse options.decoder
        , timeout = Nothing
        , tracker = Nothing
        }


{-| Send an HTTP `POST` request to your GraphQL API

    GraphQL.Http.post
        { url = "/api/graphql"
        , query = """
            query FindPerson(name: $name) {
                person(name: $name) {
                    id
                    name
                }
            }
        """
        , variables =
            [ ( "name", GraphQL.Encode.string "Doug" )
            ]
        , onResponse = ApiResponded
        , decoder = decoder
        }

-}
post :
    { url : String
    , query : String
    , variables : List ( String, GraphQL.Encode.Value )
    , decoder : GraphQL.Decode.Decoder data
    , onResponse : Result Http.Error data -> msg
    }
    -> Cmd msg
post options =
    Http.post
        { url = options.url
        , body =
            body
                { operationName = Nothing
                , query = options.query
                , variables = options.variables
                }
        , expect = expect options.onResponse options.decoder
        }


{-| Create the JSON body for your GraphQL request.

    GraphQL.Http.body
        { operationName = Just "FetchCurrentUser"
        , query = """
            query FetchCurrentUser {
                me {
                    id
                    name
                }
            }
        """
        , variables = []
        }

-}
body :
    { operationName : Maybe String
    , query : String
    , variables : List ( String, GraphQL.Encode.Value )
    }
    -> Http.Body
body options =
    let
        json : Json.Encode.Value
        json =
            [ case options.operationName of
                Just name ->
                    Just
                        ( "operationName"
                        , Json.Encode.string name
                        )

                Nothing ->
                    Nothing
            , Just
                ( "query"
                , Json.Encode.string (dedent options.query)
                )
            , Just
                ( "variables"
                , Json.Encode.object (List.map toJsonField options.variables)
                )
            ]
                |> List.filterMap identity
                |> Json.Encode.object

        toJsonField : ( String, GraphQL.Encode.Value ) -> ( String, Json.Encode.Value )
        toJsonField ( key, value ) =
            ( key
            , GraphQL.Value.toJson value
            )
    in
    Http.jsonBody json


{-| Expect a JSON response from a GraphQL API.

    fetchData : Cmd Msg
    fetchData =
        Http.request
            { -- ... other fields
            , expect =
                GraphQL.Http.expect
                    ApiResponded
                    decoder
            }

-}
expect :
    (Result Http.Error data -> msg)
    -> GraphQL.Decode.Decoder data
    -> Http.Expect msg
expect onResponse decoder =
    Http.expectJson
        onResponse
        (Json.Decode.field "data"
            (GraphQL.Internals.Decoder.toJsonDecoder decoder)
        )



-- INTERNALS


{-| Removes excess spaces from the GraphQL queries provided

    """
            query {
              me
            }
    """

    -- becomes
    """
    query {
      me
    }
    """

-}
dedent : String -> String
dedent indentedString =
    let
        lines : List String
        lines =
            String.lines indentedString

        nonBlankLines : List String
        nonBlankLines =
            List.filter isNonBlank lines

        isNonBlank : String -> Bool
        isNonBlank =
            not << String.isEmpty << String.trimLeft

        countInitialSpacesFor : String -> Int
        countInitialSpacesFor str =
            String.length str - String.length (String.trimLeft str)

        numberOfSpacesToRemove : Int
        numberOfSpacesToRemove =
            List.foldl
                (\line maybeMin ->
                    let
                        count =
                            countInitialSpacesFor line
                    in
                    case maybeMin of
                        Nothing ->
                            Just count

                        Just min ->
                            if min < count then
                                Just min

                            else
                                Just count
                )
                Nothing
                nonBlankLines
                |> Maybe.withDefault 0
    in
    nonBlankLines
        |> List.map (String.dropLeft numberOfSpacesToRemove)
        |> String.join "\n"
