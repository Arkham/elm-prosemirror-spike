module Main exposing (main)

import Browser
import Html exposing (Html)
import Html.Attributes
import Prosemirror


type alias Range =
    { start : Int
    , end : Int
    }


type alias Model =
    { selection : Range
    , doc : Prosemirror.Doc
    }


type Msg
    = DocChange Prosemirror.Doc


main : Program () Model Msg
main =
    Browser.element
        { init =
            \flags ->
                ( { selection = { start = 0, end = 0 }
                  , doc = Prosemirror.empty
                  }
                , Cmd.none
                )
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        }


view : Model -> Html Msg
view model =
    Html.section []
        [ Html.h1 [] [ Html.text "Elm Prosemirror spike" ]
        , Prosemirror.view { onChange = DocChange } model.doc
        , Html.h2 [] [ Html.text "DEBUG" ]
        , Html.div [] [ Html.text <| Debug.toString model.doc ]
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DocChange doc ->
            let
                _ =
                    Debug.log "doc changed" ()
            in
            ( { model | doc = doc }, Cmd.none )
