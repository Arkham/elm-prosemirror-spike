module Main exposing (main)

import Browser
import Html exposing (Html)
import Html.Events as Events
import Json.Decode as Decode
import Json.Encode as Encode
import Prosemirror


type CustomMark
    = Highlight String


customMarkDecoder : String -> Decode.Decoder CustomMark
customMarkDecoder name =
    case name of
        "highlight" ->
            Decode.map Highlight
                (Decode.at [ "attrs", "id" ]
                    Decode.string
                )

        other ->
            Decode.fail ("I've found a mark I don't know: " ++ other)


customMarkEncoder : CustomMark -> Encode.Value
customMarkEncoder mark =
    case mark of
        Highlight str ->
            Encode.object
                [ ( "type", Encode.string "highlight" )
                , ( "attrs"
                  , Encode.object
                        [ ( "id", Encode.string str )
                        ]
                  )
                ]


type alias Model =
    { selection : Prosemirror.Selection
    , editorState : Prosemirror.State CustomMark
    , isHighlighting : Bool
    , nextHighlightId : Int
    }


type Msg
    = DocChange ( Prosemirror.Doc CustomMark, Prosemirror.Selection )
    | ToggleHighlighting
    | PersistHighlight


main : Program () Model Msg
main =
    Browser.element
        { init =
            \flags ->
                ( { selection = { from = 0, to = 0 }
                  , editorState =
                        { doc =
                            case Decode.decodeString (Prosemirror.decoder customMarkDecoder) docJson of
                                Ok value ->
                                    value

                                Err err ->
                                    let
                                        _ =
                                            Debug.log "Error while decoding document: " err
                                    in
                                    Prosemirror.empty
                        , transactions = []
                        , nextTransactionId = 1
                        }
                  , isHighlighting = False
                  , nextHighlightId = 1
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
        , Html.div [ Events.onMouseUp PersistHighlight ]
            [ Prosemirror.view
                { markEncoder = customMarkEncoder
                , markDecoder = customMarkDecoder
                , onChange = DocChange
                }
                model.editorState
            ]
        , Html.button [ Events.onClick ToggleHighlighting ]
            [ Html.text <|
                if model.isHighlighting then
                    "Stop highlighting"

                else
                    "Start highlighting"
            ]
        , Html.h2 [] [ Html.text "DEBUG" ]
        , Html.div [] [ Html.text <| Debug.toString model.selection ]
        , Html.div [] [ Html.text <| Debug.toString model.editorState ]
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DocChange ( newDoc, selection ) ->
            let
                editorState =
                    model.editorState

                newEditorState =
                    { editorState | doc = newDoc }
            in
            ( { model | editorState = newEditorState, selection = selection }, Cmd.none )

        ToggleHighlighting ->
            ( { model | isHighlighting = not model.isHighlighting }, Cmd.none )

        PersistHighlight ->
            if model.isHighlighting && model.selection.to /= model.selection.from then
                let
                    newEditorState =
                        Prosemirror.applyTransaction
                            (Prosemirror.AddMark model.selection
                                (Prosemirror.Custom
                                    (Highlight (String.fromInt model.nextHighlightId))
                                )
                            )
                            model.editorState
                in
                ( { model | editorState = newEditorState, nextHighlightId = model.nextHighlightId + 1 }, Cmd.none )

            else
                ( model, Cmd.none )


docJson : String
docJson =
    """{"type":"doc","content":[{"type":"heading","attrs":{"level":1},"content":[{"type":"text","text":"Hello darkness my old friend"}]},{"type":"heading","attrs":{"level":3},"content":[{"type":"text","text":"I've come to talk with you again"}]},{"type":"paragraph","content":[{"type":"text","text":"lorem "},{"type":"text","marks":[{"type":"highlight","attrs":{"id":"123"}}],"text":"ipsum"},{"type":"text","text":", "},{"type":"text","marks":[{"type":"link","attrs":{"href":"www.google.com","title":null}}],"text":"google"}]},{"type":"bullet_list","content":[{"type":"list_item","content":[{"type":"paragraph","content":[{"type":"text","text":"hoho"}]}]},{"type":"list_item","content":[{"type":"paragraph","content":[{"type":"text","text":"haha"}]},{"type":"bullet_list","content":[{"type":"list_item","content":[{"type":"paragraph","content":[{"type":"text","text":"hehe"}]}]}]}]}]}]}"""
