module Prosemirror exposing (..)

import Html exposing (Html)
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as Pipeline


type Doc
    = Doc (List Content)


type Content
    = Heading Int (List InlineContent)
    | Paragraph (List InlineContent)
    | BulletList { tight : Bool } (List ListItem)


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
        Decode.at [ "detail", "state" ]
            (Decode.andThen
                (\type_ ->
                    case type_ of
                        "doc" ->
                            Decode.field "content" (Decode.list contentDecoder)

                        other ->
                            Decode.fail ("I expected to find a document at the top level, but instead I found " ++ other)
                )
                (Decode.field "type" Decode.string)
            )


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
                    Decode.map (\( tight, content ) -> BulletList { tight = tight } content)
                        bulletListDecoder

                other ->
                    Decode.fail ("I've found a type of content I don't recognize: " ++ other)
        )
        (Decode.field "type" Decode.string)


headingDecoder : Decoder ( Int, List InlineContent )
headingDecoder =
    Decode.map2 (\level contents -> ( level, contents ))
        (Decode.at [ "attrs", "level" ] Decode.int)
        (Decode.field "content" (Decode.list inlineContentDecoder))


bulletListDecoder : Decoder ( Bool, List ListItem )
bulletListDecoder =
    Decode.map2 (\tight contents -> ( tight, contents ))
        (Decode.at [ "attrs", "tight" ] Decode.bool)
        (Decode.field "content" (Decode.list listItemDecoder))


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


view : { onChange : Doc -> msg } -> Doc -> Html msg
view { onChange } (Doc contents) =
    Html.node "elm-prosemirror"
        [ Decode.map onChange (loggingDecoder decoder)
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
