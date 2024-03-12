# __@ryan-haskell/graphql__

An `elm/json` inspired package for working with GraphQL

## __Installation__

```
elm install ryan-haskell/graphql
```

## __Introduction__

When working with JSON data, folks in the Elm community use the [`elm/json`](https://package.elm-lang.org/packages/elm/json/latest) package. This is a great, general purpose library for safely handling unknown JSON sent from a backend API server.

This package builds on top of `elm/json`, adding functions designed specifically for working with [__GraphQL__](https://graphql.org/learn/). This means you can easily work with scalars, enums, object types, input types, interfaces, and union types within your Elm application.

Here's a quick overview of what each module does:

1. __`GraphQL.Decode`__ - Decode JSON responses sent from a GraphQL API
1. __`GraphQL.Encode`__ - Create JSON values to send as variables to a GraphQL API
1. __`GraphQL.Http`__ - Send HTTP requests to a GraphQL API endpoint
1. __`GraphQL.Scalar.ID`__ - Work with the built-in GraphQL `ID` scalar
1. __`GraphQL.Operation`__ - Like `GraphQL.Http`, but allows you to handle `Cmd` values in one place
1. __`GraphQL.Error`__ - Work with GraphQL validation errors

## __A quick example__

In [the official GraphQL documentation](https://graphql.org/learn/queries/), they begin their guide with a sample query that uses the _Star Wars_ GraphQL API. 

This is an example that shows how to use this package to create an HTTP request for use in your Elm application:

```elm
import GraphQL.Decode exposing (Decoder)
import GraphQL.Encode
import GraphQL.Http


type Msg
    = ApiResponded (Result GraphQL.Http.Error Data)



-- Sending a GraphQL query


findHero : String -> Cmd Msg
findHero heroId =
    GraphQL.Http.get
        { url = "/graphql"
        , query = """
            query FindHero($id: ID!) {
              hero(id: $id) {
                name
                appearsIn
              }
            }
          """
        , variables =
            [ ( "id", GraphQL.Encode.string heroId )
            ]
        , onResponse = ApiResponded
        , decoder = decoder
        }



-- Defining a GraphQL Decoder


type alias Data =
    { hero : Maybe Hero
    }


decoder : Decoder Data
decoder =
    GraphQL.Decode.object Data
        |> GraphQL.Decode.field
            { name = "hero"
            , decoder = GraphQL.Decode.maybe heroDecoder
            }


type alias Hero =
    { name : String
    , appearsIn : List Episode
    }


heroDecoder : Decoder Hero
heroDecoder =
    GraphQL.Decode.object Hero
        |> GraphQL.Decode.field
            { name = "name"
            , decoder = GraphQL.Decode.string
            }
        |> GraphQL.Decode.field
            { name = "appearsIn"
            , decoder = GraphQL.Decode.list episodeDecoder
            }


type Episode
    = NewHope
    | EmpireStrikesBack
    | ReturnOfTheJedi


episodeDecoder : Decoder Episode
episodeDecoder =
    GraphQL.Decode.enum
        [ ( "NEWHOPE", NewHope )
        , ( "EMPIRE", EmpireStrikesBack )
        , ( "JEDI", ReturnOfTheJedi )
        ]
```

### __Understanding how it works__

When you send this HTTP request, using a function like [`GraphQL.Http.post`](https://package.elm-lang.org/packages/ryan-haskell/graphql/latest/GraphQL-Http#post), the GraphQL API server will receive the following request:

```json
// POST /graphql

{
    "query": "query FindHero($id: Id!) { ... }",
    "variables": {
        "id": "1"
    }
}
```

When the API responds with a JSON payload, your decoder will convert the raw JSON into Elm values you can use in your application:

```json
// The JSON sent from the API:
{
  "data": {
    "hero": {
      "name": "R2-D2",
      "appearsIn": [
        "NEWHOPE",
        "EMPIRE",
        "JEDI"
      ]
    }
  }
}
```

```elm
-- The JSON decoded into an Elm value
data ==
    { hero =
        Just
            { name = "R2-D2"
            , appearsIn =
                [ NewHope
                , EmpireStrikesBack
                , ReturnOfTheJedi
                ]
            }
    }
```

## __Comparison with other tools__

This Elm package is for making GraphQL requests without _any_ code generation or build tools.

If you'd like to use code generation to keep your backend GraphQL schema in-sync with your Elm application, there are some great tools that include an NPM CLI to generate that code for you:

1. __[dillonkearns/elm-graphql](https://github.com/dillonkearns/elm-graphql)__ – Write Elm code, generate GraphQL
2. __[vendrinc/elm-gql](https://github.com/vendrinc/elm-gql)__ – Write GraphQL, generate Elm code
