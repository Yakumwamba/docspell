module Comp.SourceForm exposing
    ( Model
    , Msg(..)
    , getSource
    , init
    , isValid
    , update
    , view
    , view2
    )

import Api
import Api.Model.FolderItem exposing (FolderItem)
import Api.Model.FolderList exposing (FolderList)
import Api.Model.IdName exposing (IdName)
import Api.Model.SourceAndTags exposing (SourceAndTags)
import Api.Model.Tag exposing (Tag)
import Api.Model.TagList exposing (TagList)
import Comp.Basic as B
import Comp.Dropdown exposing (isDropdownChangeMsg)
import Comp.FixedDropdown
import Data.DropdownStyle as DS
import Data.Flags exposing (Flags)
import Data.Language exposing (Language)
import Data.Priority exposing (Priority)
import Data.UiSettings exposing (UiSettings)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onCheck, onInput)
import Http
import Markdown
import Styles as S
import Util.Folder exposing (mkFolderOption)
import Util.Maybe
import Util.Tag
import Util.Update


type alias Model =
    { source : SourceAndTags
    , abbrev : String
    , description : Maybe String
    , priorityModel : Comp.FixedDropdown.Model Priority
    , priority : Priority
    , enabled : Bool
    , folderModel : Comp.Dropdown.Model IdName
    , allFolders : List FolderItem
    , folderId : Maybe String
    , tagModel : Comp.Dropdown.Model Tag
    , fileFilter : Maybe String
    , languageModel : Comp.Dropdown.Model Language
    , language : Maybe String
    }


emptyModel : Model
emptyModel =
    { source = Api.Model.SourceAndTags.empty
    , abbrev = ""
    , description = Nothing
    , priorityModel =
        Comp.FixedDropdown.initMap
            Data.Priority.toName
            Data.Priority.all
    , priority = Data.Priority.Low
    , enabled = False
    , folderModel =
        Comp.Dropdown.makeSingle
            { makeOption = \e -> { value = e.id, text = e.name, additional = "" }
            , placeholder = ""
            }
    , allFolders = []
    , folderId = Nothing
    , tagModel = Util.Tag.makeDropdownModel2
    , fileFilter = Nothing
    , languageModel =
        Comp.Dropdown.makeSingleList
            { makeOption =
                \a ->
                    { value = Data.Language.toName a
                    , text = Data.Language.toName a
                    , additional = ""
                    }
            , placeholder = "Select…"
            , options = Data.Language.all
            , selected = Nothing
            }
    , language = Nothing
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( emptyModel
    , Cmd.batch
        [ Api.getFolders flags "" False GetFolderResp
        , Api.getTags flags "" GetTagResp
        ]
    )


isValid : Model -> Bool
isValid model =
    model.abbrev /= ""


getSource : Model -> SourceAndTags
getSource model =
    let
        st =
            model.source

        s =
            st.source

        tags =
            Comp.Dropdown.getSelected model.tagModel

        n =
            { s
                | abbrev = model.abbrev
                , description = model.description
                , enabled = model.enabled
                , priority = Data.Priority.toName model.priority
                , folder = model.folderId
                , fileFilter = model.fileFilter
                , language = model.language
            }
    in
    { st | source = n, tags = TagList (List.length tags) tags }


type Msg
    = SetAbbrev String
    | SetSource SourceAndTags
    | SetDescr String
    | ToggleEnabled
    | PrioDropdownMsg (Comp.FixedDropdown.Msg Priority)
    | GetFolderResp (Result Http.Error FolderList)
    | FolderDropdownMsg (Comp.Dropdown.Msg IdName)
    | GetTagResp (Result Http.Error TagList)
    | TagDropdownMsg (Comp.Dropdown.Msg Tag)
    | SetFileFilter String
    | LanguageMsg (Comp.Dropdown.Msg Language)



--- Update


update : Flags -> Msg -> Model -> ( Model, Cmd Msg )
update flags msg model =
    case msg of
        SetSource t ->
            let
                stpost =
                    model.source

                post =
                    stpost.source

                np =
                    { post
                        | id = t.source.id
                        , abbrev = t.source.abbrev
                        , description = t.source.description
                        , priority = t.source.priority
                        , enabled = t.source.enabled
                        , folder = t.source.folder
                        , fileFilter = t.source.fileFilter
                    }

                newModel =
                    { model
                        | source = { stpost | source = np }
                        , abbrev = t.source.abbrev
                        , description = t.source.description
                        , priority =
                            Data.Priority.fromString t.source.priority
                                |> Maybe.withDefault Data.Priority.Low
                        , enabled = t.source.enabled
                        , folderId = t.source.folder
                        , fileFilter = t.source.fileFilter
                    }

                mkIdName id =
                    List.filterMap
                        (\f ->
                            if f.id == id then
                                Just (IdName id f.name)

                            else
                                Nothing
                        )
                        model.allFolders

                sel =
                    case Maybe.map mkIdName t.source.folder of
                        Just idref ->
                            idref

                        Nothing ->
                            []

                tags =
                    Comp.Dropdown.SetSelection t.tags.items
            in
            Util.Update.andThen1
                [ update flags (FolderDropdownMsg (Comp.Dropdown.SetSelection sel))
                , update flags (TagDropdownMsg tags)
                ]
                newModel

        ToggleEnabled ->
            ( { model | enabled = not model.enabled }, Cmd.none )

        SetAbbrev n ->
            ( { model | abbrev = n }, Cmd.none )

        SetDescr d ->
            ( { model | description = Util.Maybe.fromString d }
            , Cmd.none
            )

        PrioDropdownMsg m ->
            let
                ( m2, p2 ) =
                    Comp.FixedDropdown.update m model.priorityModel
            in
            ( { model
                | priorityModel = m2
                , priority = Maybe.withDefault model.priority p2
              }
            , Cmd.none
            )

        GetFolderResp (Ok fs) ->
            let
                model_ =
                    { model
                        | allFolders = fs.items
                        , folderModel =
                            Comp.Dropdown.setMkOption
                                (mkFolderOption flags fs.items)
                                model.folderModel
                    }

                mkIdName fitem =
                    IdName fitem.id fitem.name

                opts =
                    fs.items
                        |> List.map mkIdName
                        |> Comp.Dropdown.SetOptions
            in
            update flags (FolderDropdownMsg opts) model_

        GetFolderResp (Err _) ->
            ( model, Cmd.none )

        FolderDropdownMsg m ->
            let
                ( m2, c2 ) =
                    Comp.Dropdown.update m model.folderModel

                newModel =
                    { model | folderModel = m2 }

                idref =
                    Comp.Dropdown.getSelected m2 |> List.head

                model_ =
                    if isDropdownChangeMsg m then
                        { newModel | folderId = Maybe.map .id idref }

                    else
                        newModel
            in
            ( model_, Cmd.map FolderDropdownMsg c2 )

        GetTagResp (Ok list) ->
            let
                opts =
                    Comp.Dropdown.SetOptions list.items
            in
            update flags (TagDropdownMsg opts) model

        GetTagResp (Err _) ->
            ( model, Cmd.none )

        TagDropdownMsg lm ->
            let
                ( m2, c2 ) =
                    Comp.Dropdown.update lm model.tagModel

                newModel =
                    { model | tagModel = m2 }
            in
            ( newModel, Cmd.map TagDropdownMsg c2 )

        SetFileFilter d ->
            ( { model | fileFilter = Util.Maybe.fromString d }
            , Cmd.none
            )

        LanguageMsg lm ->
            let
                ( dm, dc ) =
                    Comp.Dropdown.update lm model.languageModel

                newModel =
                    { model | languageModel = dm }

                lang =
                    Comp.Dropdown.getSelected dm |> List.head

                model_ =
                    if isDropdownChangeMsg lm then
                        { newModel | language = Maybe.map Data.Language.toIso3 lang }

                    else
                        newModel
            in
            ( model_
            , Cmd.map LanguageMsg dc
            )



--- View


view : Flags -> UiSettings -> Model -> Html Msg
view flags settings model =
    let
        priorityItem =
            Comp.FixedDropdown.Item
                model.priority
                (Data.Priority.toName model.priority)
    in
    div [ class "ui warning form" ]
        [ div
            [ classList
                [ ( "field", True )
                , ( "error", not (isValid model) )
                ]
            ]
            [ label [] [ text "Abbrev*" ]
            , input
                [ type_ "text"
                , onInput SetAbbrev
                , placeholder "Abbrev"
                , value model.abbrev
                ]
                []
            ]
        , div [ class "field" ]
            [ label [] [ text "Description" ]
            , textarea
                [ onInput SetDescr
                , model.description |> Maybe.withDefault "" |> value
                , rows 3
                ]
                []
            ]
        , div [ class "inline field" ]
            [ div [ class "ui checkbox" ]
                [ input
                    [ type_ "checkbox"
                    , onCheck (\_ -> ToggleEnabled)
                    , checked model.enabled
                    ]
                    []
                , label [] [ text "Enabled" ]
                ]
            ]
        , div [ class "field" ]
            [ label [] [ text "Priority" ]
            , Html.map PrioDropdownMsg
                (Comp.FixedDropdown.view
                    (Just priorityItem)
                    model.priorityModel
                )
            , div [ class "small-info" ]
                [ text "The priority used by the scheduler when processing uploaded files."
                ]
            ]
        , div [ class "ui dividing header" ]
            [ text "Metadata"
            ]
        , div [ class "ui message" ]
            [ text "Metadata specified here is automatically attached to each item uploaded "
            , text "through this source, unless it is overriden in the upload request meta data. "
            , text "Tags from the request are added to those defined here."
            ]
        , div [ class "field" ]
            [ label []
                [ text "Folder"
                ]
            , Html.map FolderDropdownMsg (Comp.Dropdown.view settings model.folderModel)
            , div [ class "small-info" ]
                [ text "Choose a folder to automatically put items into."
                ]
            , div
                [ classList
                    [ ( "ui warning message", True )
                    , ( "hidden", isFolderMember model )
                    ]
                ]
                [ Markdown.toHtml [] """
You are **not a member** of this folder. Items created through this
link will be **hidden** from any search results. Use a folder where
you are a member of to make items visible. This message will
disappear then.
                      """
                ]
            ]
        , div [ class "field" ]
            [ label [] [ text "Tags" ]
            , Html.map TagDropdownMsg (Comp.Dropdown.view settings model.tagModel)
            , div [ class "small-info" ]
                [ text "Choose tags that should be applied to items."
                ]
            ]
        , div
            [ class "field"
            ]
            [ label [] [ text "File Filter" ]
            , input
                [ type_ "text"
                , onInput SetFileFilter
                , placeholder "File Filter"
                , model.fileFilter
                    |> Maybe.withDefault ""
                    |> value
                ]
                []
            , div [ class "small-info" ]
                [ text "Specify a file glob to filter files when uploading archives "
                , text "(e.g. for email and zip). For example, to only extract pdf files: "
                , code []
                    [ text "*.pdf"
                    ]
                , text ". Globs can be combined via OR, like this: "
                , code []
                    [ text "*.pdf|mail.html"
                    ]
                ]
            ]
        ]


isFolderMember : Model -> Bool
isFolderMember model =
    let
        selected =
            Comp.Dropdown.getSelected model.folderModel
                |> List.head
                |> Maybe.map .id
    in
    Util.Folder.isFolderMember model.allFolders selected



--- View2


view2 : Flags -> UiSettings -> Model -> Html Msg
view2 _ settings model =
    let
        priorityItem =
            Comp.FixedDropdown.Item
                model.priority
                (Data.Priority.toName model.priority)
    in
    div [ class "flex flex-col" ]
        [ div [ class "mb-4" ]
            [ label
                [ for "source-abbrev"
                , class S.inputLabel
                ]
                [ text "Name"
                , B.inputRequired
                ]
            , input
                [ type_ "text"
                , id "source-abbrev"
                , onInput SetAbbrev
                , placeholder "Name"
                , value model.abbrev
                , class S.textInput
                , classList [ ( S.inputErrorBorder, not (isValid model) ) ]
                ]
                []
            ]
        , div [ class "mb-4" ]
            [ label
                [ for "source-descr"
                , class S.inputLabel
                ]
                [ text "Description"
                ]
            , textarea
                [ onInput SetDescr
                , model.description |> Maybe.withDefault "" |> value
                , rows 3
                , class S.textAreaInput
                , id "source-descr"
                ]
                []
            ]
        , div [ class "mb-4" ]
            [ label
                [ class "inline-flex items-center"
                , for "source-enabled"
                ]
                [ input
                    [ type_ "checkbox"
                    , onCheck (\_ -> ToggleEnabled)
                    , checked model.enabled
                    , class S.checkboxInput
                    , id "source-enabled"
                    ]
                    []
                , span [ class "ml-2" ]
                    [ text "Enabled"
                    ]
                ]
            ]
        , div [ class "mb-4" ]
            [ label [ class S.inputLabel ]
                [ text "Priority"
                ]
            , Html.map PrioDropdownMsg
                (Comp.FixedDropdown.view2
                    (Just priorityItem)
                    model.priorityModel
                )
            , div [ class "opacity-50 text-sm" ]
                [ text "The priority used by the scheduler when processing uploaded files."
                ]
            ]
        , div
            [ class S.header2
            , class "mt-6"
            ]
            [ text "Metadata"
            ]
        , div
            [ class S.message
            , class "mb-4"
            ]
            [ text "Metadata specified here is automatically attached to each item uploaded "
            , text "through this source, unless it is overriden in the upload request meta data. "
            , text "Tags from the request are added to those defined here."
            ]
        , div [ class "mb-4" ]
            [ label [ class S.inputLabel ]
                [ text "Folder"
                ]
            , Html.map FolderDropdownMsg
                (Comp.Dropdown.view2
                    DS.mainStyle
                    settings
                    model.folderModel
                )
            , div [ class "opacity-50 text-sm" ]
                [ text "Choose a folder to automatically put items into."
                ]
            , div
                [ classList
                    [ ( "hidden", isFolderMember2 model )
                    ]
                , class S.message
                ]
                [ Markdown.toHtml [] """
You are **not a member** of this folder. Items created through this
link will be **hidden** from any search results. Use a folder where
you are a member of to make items visible. This message will
disappear then.
                      """
                ]
            ]
        , div [ class "mb-4" ]
            [ label [ class S.inputLabel ]
                [ text "Tags" ]
            , Html.map TagDropdownMsg
                (Comp.Dropdown.view2
                    DS.mainStyle
                    settings
                    model.tagModel
                )
            , div [ class "opacity-50 text-sm" ]
                [ text "Choose tags that should be applied to items."
                ]
            ]
        , div
            [ class "mb-4"
            ]
            [ label [ class S.inputLabel ]
                [ text "File Filter" ]
            , input
                [ type_ "text"
                , onInput SetFileFilter
                , placeholder "File Filter"
                , model.fileFilter
                    |> Maybe.withDefault ""
                    |> value
                , class S.textInput
                ]
                []
            , div [ class "opacity-50 text-sm" ]
                [ text "Specify a file glob to filter files when uploading archives "
                , text "(e.g. for email and zip). For example, to only extract pdf files: "
                , code [ class "font-mono" ]
                    [ text "*.pdf"
                    ]
                , text ". Globs can be combined via OR, like this: "
                , code [ class "font-mono" ]
                    [ text "*.pdf|mail.html"
                    ]
                ]
            ]
        , div [ class "mb-4" ]
            [ label [ class S.inputLabel ]
                [ text "Language:"
                ]
            , Html.map LanguageMsg
                (Comp.Dropdown.view2
                    DS.mainStyle
                    settings
                    model.languageModel
                )
            , div [ class "text-gray-400 text-xs" ]
                [ text "Used for text extraction and analysis. The collective's "
                , text "default language is used if not specified here."
                ]
            ]
        ]


isFolderMember2 : Model -> Bool
isFolderMember2 model =
    let
        selected =
            Comp.Dropdown.getSelected model.folderModel
                |> List.head
                |> Maybe.map .id
    in
    Util.Folder.isFolderMember model.allFolders selected
