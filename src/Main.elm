module Main where

import Array exposing (Array)
import Graphics.Element as Element exposing (Element)
import Graphics.Collage as Collage
import Graphics.Input   as Input
import Color exposing (Color, red, yellow, green, blue)
import Time
import Keyboard
import Window
import Mouse
import Random
import Maybe
--import Generators

-- MODEL

type alias Model =
  { color : Color
  , counter : Int

  , level : Int
  , score : Int
  , sequence : Array ID
  , inputSequence : Array ID
  , state : GameState
  , elements : List ( ID, ElementModel )
  }

type alias ID = Int
type alias ElementModel =
  { pressed : Bool
  , position : Position
  , color : Color
  }
type alias Dimensions = (Int, Int)
type alias Position = (Float, Float)

type Action
  = NoOp
  | Add
  | Subtract
  | Press ID
  | ChangeGameState

type GameState = Play | Pause

-- extensible record
--type alias Pressable a =
--  { a | id : Int, pressed : Bool }

--type alias PressableElement = (Element, { id : Int, pressed : Bool })
--type alias Pressable = { id : Int, pressed : Bool }

initialModel : Model
initialModel =
  { color = red
  , counter = 0

  , level = 1
  , score = 0
  , sequence = initialSequence
  , inputSequence = Array.empty
  , state = Pause
  -- TODO: rename elements to squares and create a constructor for Square
  , elements =
    [ ( 1, { pressed = False, position = (-200, 160), color = red } )
    , ( 2, { pressed = False, position = (200, 160), color = yellow } )
    , ( 3, { pressed = False, position = (-200, -160), color = green } )
    , ( 4, { pressed = False, position = (200, -160), color = blue } )
    ]
  }


elementIDs : Signal.Mailbox Int
elementIDs = Signal.mailbox 0


randomIDgenerator : Random.Generator ID
randomIDgenerator =
  Random.int 1 4


randomID : Random.Seed -> (ID, Random.Seed)
randomID seed =
  Random.generate randomIDgenerator seed


initialSequence : Array ID
initialSequence =
  let
    listGenerator = Random.list 4 randomIDgenerator
    seed = Random.initialSeed 123 -- not random, always generates [2,4,2,4]
    (list, _) = Random.generate listGenerator seed
  in
    Array.fromList list

  --let
  --  (id, newSeed) = randomId model.seed
  --in
  --Array.repeat 4 randomID
  --Array.foldl randomID Array.empty
  --Array.foldl (\elem acc ->
  --  let
  --    (id, newSeed) = randomId
  --) Array.empty


--pop : Array a -> a
--pop arr =
--  let [value] = Array.slice 0 -1 arr
--  in value
-- Returns the array with only the last element.
--last : Array a -> Array a
--last a =
--  Array.slice -1 (Array.length a) a


-- UPDATE

update : Action -> Model -> Model
update action model =
  case action of
    Add      -> { model | counter = model.counter + 1 }
    Subtract -> { model | counter = model.counter - 1 }

    -- When a button is pressed, we need to check whether we are playing or not.
    -- We can potentially avoid this first check if we make sure a button will
    -- never be pressable if the game is paused (e.g. by putting a layer
    -- on top that says "Game paused").
    -- Anyway:
    -- In case we are not playing, nothing happens.
    -- If we are playing, we need to check whether a sequence is playing or not.
    ---- In case the sequence is playing, nothing happens.
    ---- If the sequence is not playing, it means we need to check whether the
    ---- inputSequence has been fully provided.
    ----------------------------------------------------------------------------
    ---- Assuming we are playing and the sequence is not playing (i.e. the game
    ---- just got an input)
    ------ If inputSequence has been fully provided then
    ------ Next level!
    ------ else we need to check whether we can update the inputSequence or not.
    -------- If the last input is correct then
    -------- update the inputSequence
    -------- else reset the game.
    -- Additionally, we also need to update the state of the button to
    -- pressed = True
    -- and all the other buttons to False.
    -- This is to ensure the button gets styled correctly.
    Press id ->
      -- if model.inputSequence.length == model.sequence.length then
      let
        index = Array.length model.inputSequence
        sequenceID = Maybe.withDefault 0 (Array.get index model.sequence)
      in
        if id == sequenceID then
          -- correct! update
          if Array.length model.inputSequence == Array.length model.sequence then
            nextLevel model
          else
            updateSequence id model
        else
          -- wrong! reset
          reset model


    ChangeGameState ->
      case model.state of
        Play  -> { model | state = Pause }
        Pause -> { model | state = Play }

    _ ->
      model


reset model =
  model


nextLevel model =
  model


updateSequence id model =
  let
    updateElement (elemId, elemModel) =
      if elemId == id
        then (elemId, { elemModel | pressed = True })
        else (elemId, { elemModel | pressed = False })
  in
    { model
      | inputSequence = Array.push id model.inputSequence
      , elements = List.map updateElement model.elements
    }


-- VIEW

view : Dimensions -> Model -> Element
view (w, h) model =
  let
    elements = List.map (viewSquare (w, h)) model.elements
    debug = showDebug True model
  in
    Collage.collage w h (elements ++ [debug])


viewSquare : Dimensions -> (ID, ElementModel) -> Collage.Form
viewSquare (w, h) (id, { pressed, position, color }) =
  let
    width = w // 2
    height = h // 2
  in
    Element.empty
    |> Element.size width height
    |> Element.color color
    |> Element.opacity (if pressed then 1 else 0.2)
    |> Input.clickable (Signal.message elementIDs.address id)
    |> Collage.toForm
    |> Collage.move position


showDebug : Bool -> Model -> Collage.Form
showDebug yes model =
  if yes then
    Element.show model
    |> Collage.toForm
    |> Collage.moveY 100
  else
    Element.empty
    |> Collage.toForm


-- MAIN

main : Signal Element
main =
  Signal.map2 view Window.dimensions game


game : Signal Model
game =
  Signal.foldp update initialModel input


input : Signal Action
input =
  let
    x = Signal.map .x Keyboard.arrows
    delta = Time.fps 30
    toAction n =
      case n of
        -1 -> Subtract
        1 -> Add
        _ -> NoOp

    arrows = Signal.sampleOn delta (Signal.map toAction x)

    clicks = Signal.map (always Add) Mouse.clicks

    elementClicks = Signal.map Press elementIDs.signal

    space = Signal.map (\pressed ->
      if pressed then ChangeGameState else NoOp
    ) Keyboard.space
  in
    Signal.mergeMany [arrows, clicks, elementClicks, space]
