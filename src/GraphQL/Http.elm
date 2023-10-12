module GraphQL.Http exposing
    ( get, post
    , Error(..)
    , body, expect
    , expectWithPartialErrors
    )

{-|


## **HTTP requests**

@docs get, post


## **Errors**

@docs Error


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


## **Partial errors**

@docs expectWithPartialErrors

-}

import Dict exposing (Dict)
import GraphQL.Decode
import GraphQL.Encode
import GraphQL.Error
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
    , onResponse : Result Error data -> msg
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
    , onResponse : Result Error data -> msg
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
            , GraphQL.Encode.toJson value
            )
    in
    Http.jsonBody json


{-| Expect a JSON response from a GraphQL API.

    type Msg
        = ApiResponded (Result GraphQL.Http.Error Data)

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
    (Result Error data -> msg)
    -> GraphQL.Decode.Decoder data
    -> Http.Expect msg
expect toMsg decoder =
    Http.expectStringResponse
        toMsg
        (fromHttpResponse
            (Json.Decode.field "data" (GraphQL.Decode.toJsonDecoder decoder))
        )


{-| According to the [GraphQL specification](https://spec.graphql.org/June2018/#example-08b62), it's possible to
receive GraphQL errors alongside a valid data response:

```json
{
  "errors": [
    {
      "message": "Name for character with ID 1002 could not be fetched.",
      "locations": [ { "line": 6, "column": 7 } ],
      "path": [ "hero", "heroFriends", 1, "name" ]
    }
  ],
  "data": {
    "hero": {
      "name": "R2-D2",
      "heroFriends": [
        {
          "id": "1000",
          "name": "Luke Skywalker"
        },
        null,
        {
          "id": "1003",
          "name": "Leia Organa"
        }
      ]
    }
  }
}
```

If your application needs to access those partial error responses,
use this rather than the simpler `expect` function:

    type Msg
        = ApiResponded
            (Result GraphQL.Http.Error
                { data : Data
                , errors : List GraphQL.Error.Error
                }
            )

    fetchData : Cmd Msg
    fetchData =
        Http.request
            { -- ... other fields
            , expect =
                GraphQL.Http.expectWithPartialErrors
                    ApiResponded
                    decoder
            }

-}
expectWithPartialErrors :
    (Result
        Error
        { data : data
        , errors : List GraphQL.Error.Error
        }
     -> msg
    )
    -> GraphQL.Decode.Decoder data
    -> Http.Expect msg
expectWithPartialErrors toMsg decoder =
    Http.expectStringResponse toMsg
        (fromHttpResponse
            (Json.Decode.map2 PartialErrors
                (Json.Decode.field "data" (GraphQL.Decode.toJsonDecoder decoder))
                (Json.Decode.oneOf
                    [ errorsDecoder
                    , Json.Decode.succeed []
                    ]
                )
            )
        )


type alias PartialErrors data =
    { data : data
    , errors : List GraphQL.Error.Error
    }



-- ERRORS


{-| When something goes wrong with the GraphQL request, this error type
will be returned with your `Result`.

This extends the default `Http.Error` to include more context and
GraphQL specific errors returned from the API.

-}
type Error
    = BadUrl String
    | Timeout
    | NetworkError
    | GraphQL { errors : List GraphQL.Error.Error }
    | UnexpectedResponse
        { url : String
        , statusCode : Int
        , statusText : String
        , headers : Dict String String
        , body : String
        , jsonError : Maybe Json.Decode.Error
        }


fromHttpResponse :
    Json.Decode.Decoder value
    -> Http.Response String
    -> Result Error value
fromHttpResponse decoder response =
    let
        handleUnexpectedResponse :
            Bool
            -> Http.Metadata
            -> String
            -> Result Error value
        handleUnexpectedResponse isGoodStatusCode metadata body_ =
            let
                toUnexpected : Maybe Json.Decode.Error -> Error
                toUnexpected maybeJsonError =
                    UnexpectedResponse
                        { url = metadata.url
                        , statusCode = metadata.statusCode
                        , statusText = metadata.statusText
                        , headers = metadata.headers
                        , body = body_
                        , jsonError = maybeJsonError
                        }
            in
            case Json.Decode.decodeString decoder body_ of
                Ok data ->
                    if isGoodStatusCode then
                        Ok data

                    else
                        -- If we get valid data, but a bad status code, we still fail
                        Err (toUnexpected Nothing)

                Err jsonDecodeError ->
                    case
                        Json.Decode.decodeString
                            errorsDecoder
                            body_
                    of
                        Ok errors ->
                            Err (GraphQL { errors = errors })

                        Err _ ->
                            Err (toUnexpected (Just jsonDecodeError))
    in
    case response of
        Http.BadUrl_ url ->
            Err (BadUrl url)

        Http.Timeout_ ->
            Err Timeout

        Http.NetworkError_ ->
            Err NetworkError

        Http.BadStatus_ metadata body_ ->
            handleUnexpectedResponse False metadata body_

        Http.GoodStatus_ metadata body_ ->
            handleUnexpectedResponse True metadata body_


errorsDecoder : Json.Decode.Decoder (List GraphQL.Error.Error)
errorsDecoder =
    Json.Decode.field "errors" (Json.Decode.list errorDecoder)


errorDecoder : Json.Decode.Decoder GraphQL.Error.Error
errorDecoder =
    Json.Decode.map4 GraphQL.Error.Error
        (Json.Decode.field "message" Json.Decode.string)
        (Json.Decode.oneOf
            [ Json.Decode.field "locations" (Json.Decode.list locationDecoder)
            , Json.Decode.succeed []
            ]
        )
        (Json.Decode.oneOf
            [ Json.Decode.field "path" (Json.Decode.list pathSegmentDecoder)
            , Json.Decode.succeed []
            ]
        )
        (Json.Decode.oneOf
            [ Json.Decode.field "extensions" (Json.Decode.dict Json.Decode.value)
            , Json.Decode.succeed Dict.empty
            ]
        )


locationDecoder : Json.Decode.Decoder GraphQL.Error.Location
locationDecoder =
    Json.Decode.map2 GraphQL.Error.Location
        (Json.Decode.field "line" Json.Decode.int)
        (Json.Decode.field "column" Json.Decode.int)


pathSegmentDecoder : Json.Decode.Decoder GraphQL.Error.PathSegment
pathSegmentDecoder =
    Json.Decode.oneOf
        [ Json.Decode.map GraphQL.Error.Index Json.Decode.int
        , Json.Decode.map GraphQL.Error.Field Json.Decode.string
        ]



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
