module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (attribute, class, classList, href, src, target, type_, width)
import Html.Events exposing (onClick)
import Http
import Json.Decode as Decode exposing (Decoder, Value)
import Json.Decode.Pipeline as Pipeline exposing (decode, optional, required)


{--Model
The `initialModel` function initializes our Model. This function is called in `init` and outputs a Model
--}


initialModel : String -> Model
initialModel url =
    { errorMessage = ""
    , portfolio =
        { categories = []
        , items = []
        }
    , selectedCategoryId = Nothing
    , selectedItemId = Nothing
    , apiUrl = url
    }


type alias Model =
    { errorMessage : String
    , portfolio : Portfolio
    , selectedCategoryId : Maybe Int
    , selectedItemId : Maybe Int
    , apiUrl : String
    }


type alias Portfolio =
    { categories : List Category
    , items : List Item
    }


type alias Category =
    { id : Int, label : String }


type alias Item =
    { id : Int
    , title : String
    , categoryId : Int
    , imageUrl : String
    , linkUrl : String
    , description : String
    , overlayColor : String
    }



{--View
The function `view` renders an Html element using our application model.
Note that the type signature is Model -> Html Msg. This means that this function transforms an argument
of Model into an Html element would produce messages tagged with Msg.

We will see this when we introduce some interaction.
--}


view : Model -> Html Msg
view model =
    let
        portfolio =
            model.portfolio

        selectedCategoryId =
            getSelectedCategoryId model

        selectedItem =
            getSelectedItem model selectedCategoryId
    in
    div [ class "container" ]
        [ div [ class "row" ]
            [ div
                [ class "col"
                ]
                [ br [] [] ]
            ]
        , div [ class "row" ]
            [ div
                [ class "col"
                ]
                [ h1 [] [ text "Elmfolio" ] ]
            ]
        , viewCategoryNavbar portfolio selectedCategoryId
        , viewSelectedItem selectedItem
        , viewItems model selectedCategoryId selectedItem
        ]


viewCategoryNavbar : Portfolio -> Int -> Html Msg
viewCategoryNavbar { categories } selectedCategoryId =
    div [ class "row" ]
        [ div
            [ class "col" ]
            [ div [ class "nav-category" ]
                (List.map (viewCategoryButton selectedCategoryId) categories)
            ]
        ]


viewCategoryButton : Int -> Category -> Html Msg
viewCategoryButton selectedCategoryId category =
    let
        categorySelected =
            selectedCategoryId == category.id

        buttonsBaseAttrs =
            [ type_ "button", classes ]

        buttonOnClick =
            if categorySelected then
                []
            else
                [ onClick (CategoryClicked category.id) ]

        buttonAttrs =
            buttonsBaseAttrs ++ buttonOnClick

        classes =
            classList
                [ ( "btn btn-category", True )
                , ( "btn-primary", categorySelected )
                , ( "btn-secondary", not categorySelected )
                ]
    in
    button buttonAttrs [ text category.label ]


viewItems : Model -> Int -> Maybe Item -> Html Msg
viewItems { portfolio, errorMessage } selectedCategoryId selectedItemId =
    let
        filteredItems =
            portfolio.items |> List.filter (\i -> i.categoryId == selectedCategoryId) |> List.map viewItem

        contents =
            if String.isEmpty errorMessage then
                div [ class "row items-container" ]
                    filteredItems
            else
                viewError errorMessage
    in
    contents


viewItem : Item -> Html Msg
viewItem item =
    div
        [ class "col-4 item-panel" ]
        [ img
            [ src item.imageUrl
            , class "img-fluid"
            , onClick (ItemClicked item.id)
            ]
            []
        ]


viewSelectedItem : Maybe Item -> Html msg
viewSelectedItem item =
    let
        contents =
            case item of
                Nothing ->
                    []

                Just detail ->
                    [ div [ class "col-6" ]
                        [ img [ src detail.imageUrl, class "img-fluid" ] [] ]
                    , div [ class "col-6" ]
                        [ h3 [] [ text detail.title ]
                        , hr [] []
                        , text detail.description
                        , br [] []
                        , br [] []
                        , a [ href detail.linkUrl, target "_blank" ] [ text detail.linkUrl ]
                        ]
                    ]
    in
    div [ class "row selected-item-container" ]
        contents


viewError : String -> Html Msg
viewError error =
    div [ class "alert alert-danger", attribute "role" "alert" ]
        [ strong []
            [ text error ]
        ]



{--Update--
The `update` function will be called by Html.program each time a message is received.
This update function responds to messages (Msg), updating the model and returning commands as needed.
--}


type Msg
    = ApiResponse (Result Http.Error Portfolio)
    | CategoryClicked Int
    | ItemClicked Int
    | None


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ApiResponse response ->
            case response of
                Ok response ->
                    let
                        updatedModel =
                            { model | portfolio = response }
                    in
                    ( updatedModel, Cmd.none )

                Err error ->
                    let
                        errorMessage =
                            "An error occurred: " ++ toString error
                    in
                    ( { model | errorMessage = errorMessage }, Cmd.none )

        CategoryClicked categoryId ->
            let
                updatedModel =
                    { model
                        | selectedCategoryId = Just categoryId
                        , selectedItemId = Nothing
                    }
            in
            ( updatedModel, Cmd.none )

        ItemClicked itemId ->
            let
                updatedModel =
                    { model
                        | selectedItemId = Just itemId
                    }
            in
            ( updatedModel, Cmd.none )

        None ->
            ( model, Cmd.none )



-- Http


getPortfolio : String -> Cmd Msg
getPortfolio url =
    Http.send ApiResponse (Http.get url portfolioDecoder)



-- JSON Decoding


portfolioDecoder : Decoder Portfolio
portfolioDecoder =
    decode Portfolio
        |> required "categories" (Decode.list categoryDecoder)
        |> required "items" (Decode.list itemDecoder)


categoryDecoder : Decoder Category
categoryDecoder =
    decode Category
        |> required "id" Decode.int
        |> required "label" Decode.string


itemDecoder : Decoder Item
itemDecoder =
    decode Item
        |> required "id" Decode.int
        |> required "title" Decode.string
        |> required "categoryId" Decode.int
        |> required "imageUrl" Decode.string
        |> required "linkUrl" Decode.string
        |> required "description" Decode.string
        |> required "overlayColor" Decode.string



-- Helpers


(=>) : a -> b -> ( a, b )
(=>) =
    (,)


getSelectedCategoryId : Model -> Int
getSelectedCategoryId { portfolio, selectedCategoryId } =
    let
        firstCategory =
            portfolio.categories
                |> List.head
                |> Maybe.map .id
                |> Maybe.withDefault 1

        updatedSelectedCategoryId =
            case selectedCategoryId of
                Nothing ->
                    firstCategory

                Just selected ->
                    selected
    in
    updatedSelectedCategoryId


getSelectedItem : Model -> Int -> Maybe Item
getSelectedItem { portfolio, selectedItemId } selectedCategoryId =
    case selectedItemId of
        Nothing ->
            Nothing

        Just id ->
            portfolio.items
                |> List.filter (\i -> i.id == id && i.categoryId == selectedCategoryId)
                |> List.head



{--Subscriptions
In Elm, using subscriptions is how your application can listen for external input. Some examples are:
 - Keyboard events
 - Mouse movements
 - Browser locations changes
 - Websocket events

In this application, we don't have a need for any active subscriptions so we add in Sub.none
--}


subscriptions =
    \_ -> Sub.none



{--Program setup and initialization--}
{--
The `main` function is the entry point for our app which means it's the first thing that is run
--}


main : Program Never Model Msg
main =
    Html.program
        { view = view
        , update = update
        , init = init "http://www.mocky.io/v2/59f8cfa92d0000891dad41ed"
        , subscriptions = subscriptions
        }



{--The `init` function is run by `main` upon application startup and allows us to set
our app's initial state as well as scheduling any commands we'd like to run after the app starts
up. For now, we don't need to run any commands so we'll use Cmd.none here.
--}


init : String -> ( Model, Cmd Msg )
init url =
    ( initialModel url, getPortfolio url )
