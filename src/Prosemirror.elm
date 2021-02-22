module Prosemirror exposing (Doc, decoder, empty, view)

import Html exposing (Html)
import Html.Attributes exposing (property)
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as Pipeline
import Json.Encode as Encode


type Doc
    = Doc (List Content)


type Content
    = Heading Int (List InlineContent)
    | Paragraph (List InlineContent)
    | BulletList (List ListItem)


type InlineContent
    = InlineContent (List Mark) String


type Mark
    = Bold
    | Italics
    | Link { href : String, title : Maybe String }


type ListItem
    = ListItem (List Content)


empty : Doc
empty =
    Doc []



-- decoders


decoder : Decoder Doc
decoder =
    Decode.map Doc <|
        Decode.andThen
            (\type_ ->
                case type_ of
                    "doc" ->
                        Decode.field "content" (Decode.list contentDecoder)

                    other ->
                        Decode.fail ("I expected to find a document at the top level, but instead I found " ++ other)
            )
            (Decode.field "type" Decode.string)


contentDecoder : Decoder Content
contentDecoder =
    Decode.andThen
        (\type_ ->
            case type_ of
                "heading" ->
                    Decode.map (\( level, content ) -> Heading level content)
                        headingDecoder

                "paragraph" ->
                    Decode.map Paragraph
                        (Decode.field "content" (Decode.list inlineContentDecoder))

                "bullet_list" ->
                    Decode.map BulletList
                        (Decode.field "content" (Decode.list listItemDecoder))

                other ->
                    Decode.fail ("I've found a type of content I don't recognize: " ++ other)
        )
        (Decode.field "type" Decode.string)


headingDecoder : Decoder ( Int, List InlineContent )
headingDecoder =
    Decode.map2 (\level contents -> ( level, contents ))
        (Decode.at [ "attrs", "level" ] Decode.int)
        (Decode.field "content" (Decode.list inlineContentDecoder))


listItemDecoder : Decoder ListItem
listItemDecoder =
    Decode.map ListItem
        (Decode.field "type" Decode.string
            |> Decode.andThen
                (\type_ ->
                    case type_ of
                        "list_item" ->
                            Decode.field "content" (Decode.list contentDecoder)

                        other ->
                            Decode.fail ("I expected to find all list items, but instead I found " ++ other)
                )
        )


inlineContentDecoder : Decoder InlineContent
inlineContentDecoder =
    Decode.succeed InlineContent
        |> Pipeline.optional "marks" (Decode.list markDecoder) []
        |> Pipeline.required "text" Decode.string


markDecoder : Decoder Mark
markDecoder =
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

                    other ->
                        Decode.fail ("I've found a mark I don't recognize: " ++ other)
            )



-- encoder


encode : Doc -> Encode.Value
encode (Doc content) =
    Encode.object
        [ ( "type", Encode.string "doc" )
        , ( "content", Encode.list encodeContent content )
        ]


encodeContent : Content -> Encode.Value
encodeContent content =
    case content of
        Heading level inlines ->
            Encode.object
                [ ( "type", Encode.string "heading" )
                , ( "attrs", Encode.object [ ( "level", Encode.int level ) ] )
                , ( "content", Encode.list encodeInline inlines )
                ]

        Paragraph inlines ->
            Encode.object
                [ ( "type", Encode.string "paragraph" )
                , ( "content", Encode.list encodeInline inlines )
                ]

        BulletList listItems ->
            Encode.object
                [ ( "type", Encode.string "bullet_list" )
                , ( "content", Encode.list encodeListItem listItems )
                ]


encodeInline : InlineContent -> Encode.Value
encodeInline (InlineContent marks text) =
    Encode.object <|
        List.concat
            [ [ ( "type", Encode.string "text" ) ]
            , case marks of
                [] ->
                    []

                _ ->
                    [ ( "marks", Encode.list encodeMark marks ) ]
            , [ ( "text", Encode.string text ) ]
            ]


encodeListItem : ListItem -> Encode.Value
encodeListItem (ListItem contents) =
    Encode.object
        [ ( "type", Encode.string "list_item" )
        , ( "content", Encode.list encodeContent contents )
        ]


encodeMark : Mark -> Encode.Value
encodeMark mark =
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



-- VIEW


view : { onChange : Doc -> msg } -> Doc -> Html msg
view { onChange } doc =
    Html.node "elm-prosemirror"
        [ property "content" (encode doc)
        , Decode.map onChange (loggingDecoder (Decode.at [ "detail", "state" ] decoder))
            |> Events.on "change"
        ]
        []


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
