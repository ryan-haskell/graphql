module GraphQL.Error exposing
    ( Error
    , Location, PathSegment(..)
    )

{-| Your GraphQL API might return a [validation](https://graphql.org/learn/validation/) response like this one:

```json
{
  "errors": [
    {
      "message": "Cannot query field \"nam\" on type \"Droid\".",
      "locations": [
        {
          "line": 4,
          "column": 5
        }
      ]
    }
  ]
}
```

This module defines the GraphQL "error" type, to help parse any validation issues within your Elm application.


## **Error**

@docs Error
@docs Location, PathSegment


## **Partial errors**

It's also possible for your GraphQL response to return **partial errors**, meaning that
both the `data` fields _and_ the _errors_ field could come back in the same response.

If your application would like to access those partial errors, use either of these two functions:

  - [`GraphQL.Http.expectWithPartialErrors`](./GraphQL-Http#expectWithPartialErrors)
  - [`GraphQL.Operation.toHttpCmdWithPartialErrors`](./GraphQL-Operation#toHttpCmdWithPartialErrors)

**Note:** This will make your `Msg` result values more complicated:

```elm
-- 1️⃣ BEFORE

type Msg
    = ApiResponded (Result GraphQL.Http.Error Data)


-- 2️⃣ AFTER

type Msg
    = ApiResponded
        (Result GraphQL.Http.Error
            { data : Data
            , errors : List Error
            }
        )
```

-}

import Dict exposing (Dict)
import Json.Decode


{-| A validation error returned by your GraphQL API.
-}
type alias Error =
    { message : String
    , locations : List Location
    , path : List PathSegment
    , extensions : Dict String Json.Decode.Value
    }


{-| Represents a location in your query/mutation
-}
type alias Location =
    { line : Int
    , column : Int
    }


{-| Helps identify which field might be causing problems
-}
type PathSegment
    = Index Int
    | Field String
