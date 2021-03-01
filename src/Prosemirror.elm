module Prosemirror exposing (Doc, Selection, decoder, empty, view)

import Html exposing (Html)
import Html.Attributes exposing (property)
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as Pipeline
import Json.Encode as Encode


type Doc a
    = Doc (List (Content a))


type alias Selection =
    { from : Int
    , to : Int
    }


type Content a
    = Heading Int (List (InlineContent a))
    | Paragraph (List (InlineContent a))
    | BulletList (List (ListItem a))


type InlineContent a
    = InlineContent (List (Mark a)) String


type Mark a
    = Bold
    | Italics
    | Link { href : String, title : Maybe String }
    | Custom a


type ListItem a
    = ListItem (List (Content a))


empty : Doc a
empty =
    Doc []



-- decoders


decoder : (String -> Decoder a) -> Decoder (Doc a)
decoder customDecoder =
    Decode.map Doc <|
        Decode.andThen
            (\type_ ->
                case type_ of
                    "doc" ->
                        Decode.field "content" (Decode.list (contentDecoder customDecoder))

                    other ->
                        Decode.fail ("I expected to find a document at the top level, but instead I found " ++ other)
            )
            (Decode.field "type" Decode.string)


contentDecoder : (String -> Decoder a) -> Decoder (Content a)
contentDecoder customDecoder =
    Decode.andThen
        (\type_ ->
            case type_ of
                "heading" ->
                    Decode.map (\( level, content ) -> Heading level content)
                        (headingDecoder customDecoder)

                "paragraph" ->
                    Decode.map Paragraph
                        (Decode.field "content" (Decode.list (inlineContentDecoder customDecoder)))

                "bullet_list" ->
                    Decode.map BulletList
                        (Decode.field "content" (Decode.list (listItemDecoder customDecoder)))

                other ->
                    Decode.fail ("I've found a type of content I don't recognize: " ++ other)
        )
        (Decode.field "type" Decode.string)


headingDecoder : (String -> Decoder a) -> Decoder ( Int, List (InlineContent a) )
headingDecoder customDecoder =
    Decode.map2 (\level contents -> ( level, contents ))
        (Decode.at [ "attrs", "level" ] Decode.int)
        (Decode.field "content" (Decode.list (inlineContentDecoder customDecoder)))


listItemDecoder : (String -> Decoder a) -> Decoder (ListItem a)
listItemDecoder customDecoder =
    Decode.map ListItem
        (Decode.field "type" Decode.string
            |> Decode.andThen
                (\type_ ->
                    case type_ of
                        "list_item" ->
                            Decode.field "content" (Decode.list (contentDecoder customDecoder))

                        other ->
                            Decode.fail ("I expected to find all list items, but instead I found " ++ other)
                )
        )


inlineContentDecoder : (String -> Decoder a) -> Decoder (InlineContent a)
inlineContentDecoder customDecoder =
    Decode.succeed InlineContent
        |> Pipeline.optional "marks" (Decode.list (markDecoder customDecoder)) []
        |> Pipeline.required "text" Decode.string


markDecoder : (String -> Decoder a) -> Decoder (Mark a)
markDecoder customDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\type_ ->
                case type_ of
                    "strong" ->
                        Decode.succeed Bold

                    "em" ->
                        Decode.succeed Italics

                    "link" ->
                        Decode.map2 (\href title -> Link { href = href, title = title })
                            (Decode.at [ "attrs", "href" ] Decode.string)
                            (Decode.at [ "attrs", "title" ] (Decode.nullable Decode.string))

                    name ->
                        Decode.map Custom (customDecoder name)
            )



-- encoder


type alias CustomEncoder a =
    a -> Encode.Value


encode : CustomEncoder a -> Doc a -> Encode.Value
encode customEncoder (Doc content) =
    Encode.object
        [ ( "type", Encode.string "doc" )
        , ( "content", Encode.list (encodeContent customEncoder) content )
        ]


encodeContent : CustomEncoder a -> Content a -> Encode.Value
encodeContent customEncoder content =
    case content of
        Heading level inlines ->
            Encode.object
                [ ( "type", Encode.string "heading" )
                , ( "attrs", Encode.object [ ( "level", Encode.int level ) ] )
                , ( "content", Encode.list (encodeInline customEncoder) inlines )
                ]

        Paragraph inlines ->
            Encode.object
                [ ( "type", Encode.string "paragraph" )
                , ( "content", Encode.list (encodeInline customEncoder) inlines )
                ]

        BulletList listItems ->
            Encode.object
                [ ( "type", Encode.string "bullet_list" )
                , ( "content", Encode.list (encodeListItem customEncoder) listItems )
                ]


encodeInline : CustomEncoder a -> InlineContent a -> Encode.Value
encodeInline customEncoder (InlineContent marks text) =
    Encode.object <|
        List.concat
            [ [ ( "type", Encode.string "text" ) ]
            , case marks of
                [] ->
                    []

                _ ->
                    [ ( "marks", Encode.list (encodeMark customEncoder) marks ) ]
            , [ ( "text", Encode.string text ) ]
            ]


encodeListItem : CustomEncoder a -> ListItem a -> Encode.Value
encodeListItem customEncoder (ListItem contents) =
    Encode.object
        [ ( "type", Encode.string "list_item" )
        , ( "content", Encode.list (encodeContent customEncoder) contents )
        ]


encodeMark : CustomEncoder a -> Mark a -> Encode.Value
encodeMark customEncoder mark =
    case mark of
        Bold ->
            Encode.object [ ( "type", Encode.string "strong" ) ]

        Italics ->
            Encode.object [ ( "type", Encode.string "em" ) ]

        Link { href, title } ->
            Encode.object
                [ ( "type", Encode.string "link" )
                , ( "attrs"
                  , Encode.object
                        [ ( "href", Encode.string href )
                        , ( "title"
                          , case title of
                                Just value ->
                                    Encode.string value

                                Nothing ->
                                    Encode.null
                          )
                        ]
                  )
                ]

        Custom other ->
            customEncoder other



-- VIEW


view :
    { onChange : ( Doc a, Selection ) -> msg
    , markEncoder : a -> Encode.Value
    , markDecoder : String -> Decoder a
    }
    -> Doc a
    -> Html msg
view config doc =
    Html.node "elm-prosemirror"
        [ property "content" (encode config.markEncoder doc)
        , Events.on "change" <|
            Decode.map2 (\state selection -> config.onChange ( state, selection ))
                (Decode.at [ "detail", "state" ] (loggingDecoder (decoder config.markDecoder)))
                (Decode.at [ "detail", "selection" ] (loggingDecoder selectionDecoder))
        ]
        []


selectionDecoder : Decoder Selection
selectionDecoder =
    Decode.map2 Selection
        (Decode.field "from" Decode.int)
        (Decode.field "to" Decode.int)


loggingDecoder : Decoder a -> Decoder a
loggingDecoder realDecoder =
    Decode.value
        |> Decode.andThen
            (\event ->
                case Decode.decodeValue realDecoder event of
                    Ok decoded ->
                        Decode.succeed decoded

                    Err error ->
                        error
                            |> Decode.errorToString
                            |> Debug.log "decoding error"
                            |> Decode.fail
            )
