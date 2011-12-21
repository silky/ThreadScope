module GUI.SummaryView (
    InfoView,
    runViewNew,
    summaryViewNew,
    runViewSetEvents,
    summaryViewSetEvents,
  ) where

import GHC.RTS.Events

import GUI.Timeline.Render.Constants

import Graphics.UI.Gtk
import Graphics.Rendering.Cairo

import Control.Monad.Reader
import Data.Array
import Data.IORef
import qualified Data.List as L

-------------------------------------------------------------------------------

data InfoView = InfoView
     { gtkLayout :: !Layout
     , stateRef :: !(IORef InfoState)
     }

data InfoState
   = InfoEmpty
   | InfoLoaded
     { infoState :: String
     }

-------------------------------------------------------------------------------

infoViewNew :: String -> Builder -> IO InfoView
infoViewNew widgetName builder = do

  stateRef <- newIORef undefined
  let getWidget cast = builderGetObject builder cast
  gtkLayout  <- getWidget castToLayout widgetName
  writeIORef stateRef InfoEmpty
  let infoView = InfoView{..}

  -- Drawing
  on gtkLayout exposeEvent $ liftIO $ do
    drawInfo infoView =<< readIORef stateRef
    return True

  return infoView

runViewNew :: Builder -> IO InfoView
runViewNew = infoViewNew "eventsLayoutRun"

summaryViewNew :: Builder -> IO InfoView
summaryViewNew = infoViewNew "eventsLayoutRun"  -- TODO: "eventsLayoutSummary"

-------------------------------------------------------------------------------

infoViewSetEvents :: (Array Int CapEvent -> InfoState)
                  -> InfoView -> Maybe (Array Int CapEvent) -> IO ()
infoViewSetEvents f InfoView{gtkLayout, stateRef} mevents = do
  let infoState = case mevents of
        Nothing     -> InfoEmpty
        Just events -> f events
  writeIORef stateRef infoState
  widgetQueueDraw gtkLayout

runViewProcessEvents :: Array Int CapEvent -> InfoState
runViewProcessEvents events =
  let showEnv env = (5, "Program environment:") : zip [6..] (map ("   " ++) env)
      showEvent (CapEvent _cap (Event _time spec)) acc =
        case spec of
          RtsIdentifier _ i  ->
            (2, "Haskell RTS name:  " ++ "\"" ++ i ++ "\"") : acc
          ProgramArgs _ args ->
            (3, "Program name:  " ++ "\"" ++ head args ++ "\"") :
            (4, "Program arguments:  " ++ show (tail args)) :
            acc
          ProgramEnv _ env   -> acc ++ showEnv env
          _                  -> acc
      start = [(1, "Program start time:  how to get it?")]
      showInfo = unlines . map snd . L.sort . foldr showEvent start . elems
  in InfoLoaded (showInfo events)

runViewSetEvents :: InfoView -> Maybe (Array Int CapEvent) -> IO ()
runViewSetEvents = infoViewSetEvents runViewProcessEvents

summaryViewProcessEvents :: Array Int CapEvent -> InfoState
summaryViewProcessEvents _events = InfoLoaded "TODO"

summaryViewSetEvents :: InfoView -> Maybe (Array Int CapEvent) -> IO ()
summaryViewSetEvents = infoViewSetEvents summaryViewProcessEvents

-------------------------------------------------------------------------------

drawInfo :: InfoView -> InfoState -> IO ()
drawInfo _ InfoEmpty = return ()
drawInfo InfoView{gtkLayout} InfoLoaded{..} = do
  win <- layoutGetDrawWindow gtkLayout
  pangoCtx <- widgetGetPangoContext gtkLayout
  layout <- layoutText pangoCtx infoState
  (_, Rectangle _ _ width height) <- layoutGetPixelExtents layout
  layoutSetSize gtkLayout (width + 30) (height + 30)
  renderWithDrawable win $ do
    moveTo (fromIntegral ox / 2) (fromIntegral ox / 3)
    showLayout layout