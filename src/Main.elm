module Main exposing (main)

import Browser
import Html exposing (Html)
import Html.Attributes
import Json.Decode as Decode
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
                  , doc =
                        case Decode.decodeString Prosemirror.decoder docJson of
                            Ok value ->
                                value

                            Err err ->
                                let
                                    _ =
                                        Debug.log "Error while decoding document: " err
                                in
                                Prosemirror.empty
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
            ( { model | doc = doc }, Cmd.none )


docJson : String
docJson =
    """{"type":"doc","content":[{"type":"heading","attrs":{"level":1},"content":[{"type":"text","text":"Hello darkness my old friend"}]},{"type":"heading","attrs":{"level":3},"content":[{"type":"text","text":"I've come to talk with you again"}]},{"type":"paragraph","content":[{"type":"text","text":"lorem ipsum, "},{"type":"text","marks":[{"type":"link","attrs":{"href":"www.google.com","title":null}}],"text":"google"}]},{"type":"bullet_list","content":[{"type":"list_item","content":[{"type":"paragraph","content":[{"type":"text","text":"hoho"}]}]},{"type":"list_item","content":[{"type":"paragraph","content":[{"type":"text","text":"haha"}]},{"type":"bullet_list","content":[{"type":"list_item","content":[{"type":"paragraph","content":[{"type":"text","text":"hehe"}]}]}]}]}]}]}"""
