module Main exposing (main)

import Browser
import Html exposing (Html)
import Html.Attributes


type alias Model =
    {}


type Msg
    = NoOp


main : Program () Model Msg
main =
    Browser.element
        { init = \flags -> ( {}, Cmd.none )
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        }


view : Model -> Html msg
view model =
    Html.section []
        [ Html.h1 [] [ Html.text "Elm Prosemirror spike" ]
        , Html.node "elm-prosemirror" [] []
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )
