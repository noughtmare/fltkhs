{-# LANGUAGE OverloadedStrings, CPP, TypeSynonymInstances, FlexibleInstances, MultiParamTypeClasses, FlexibleContexts, UndecidableInstances #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
module Graphics.UI.FLTK.LowLevel.Base.Tabs
    (
     tabsNew,
     tabsCustom,
     TabsHeightOffset(..),
     CustomTabFuncs(..)
  , drawTabsBase
  , handleTabsBase
  , resizeTabsBase
  , hideTabsBase
  , showWidgetTabsBase
     -- * Hierarchy
     --
     -- $hierarchy

     -- * Functions
     --
     -- $functions
    )
where

#include "Fl_ExportMacros.h"
#include "Fl_Types.h"
#include "Fl_TabsC.h"
import C2HS hiding (cFromEnum, cFromBool, cToBool,cToEnum)
import Graphics.UI.FLTK.LowLevel.Base.Widget
import Graphics.UI.FLTK.LowLevel.Fl_Enumerations
import Graphics.UI.FLTK.LowLevel.Fl_Types
import Graphics.UI.FLTK.LowLevel.Utils
import Graphics.UI.FLTK.LowLevel.Dispatch
import qualified Data.Text as T
import Graphics.UI.FLTK.LowLevel.Hierarchy

data TabsHeightOffset = TabsAtTop (Maybe Int) | TabsAtBottom (Maybe Int)
tabsHeightOffsetToInt :: TabsHeightOffset -> Int
tabsHeightOffsetToInt h =
  case h of
    TabsAtTop Nothing -> 0
    TabsAtTop (Just o) -> o
    TabsAtBottom Nothing -> (-1)
    TabsAtBottom (Just o) -> (-o)

intToTabsHeightOffset :: Int -> TabsHeightOffset
intToTabsHeightOffset tabh =
  case tabh of
    _ | tabh == 0 -> TabsAtTop Nothing
      | tabh == (-1) -> TabsAtBottom Nothing
      | tabh > 0 -> TabsAtTop (Just (fromIntegral tabh))
      | otherwise -> TabsAtBottom (Just (fromIntegral tabh))

data CustomTabFuncs a =
  CustomTabFuncs
  {
    tabDrawCustom :: Ref a -> IO ()
  , tabPositionsCustom :: Ref a -> IO (Maybe AtIndex, Int, [(X,Width)])
  , tabHeightCustom :: Ref a -> IO Height
  , tabWhichCustom :: Ref a -> Position -> IO (Maybe (AtIndex, Ref WidgetBase))
  , tabRedrawTabs :: Ref a -> IO ()
  , tabClientArea :: Ref a -> TabsHeightOffset -> IO Rectangle
  }

toTabClientAreaPrim :: (Ref a -> TabsHeightOffset -> IO Rectangle) -> IO (FunPtr TabClientAreaPrim)
toTabClientAreaPrim f =
  mkTabClientAreaPrim (\tabPtr xPtr yPtr wPtr hPtr tabh -> do
                          pp <- wrapNonNull tabPtr "Null pointer. toTabClientAreaPrim"
                          rect <- f (castTo (wrapInRef pp)) (intToTabsHeightOffset (fromIntegral tabh))
                          let (clientX, clientY, clientW, clientH) = fromRectangle rect
                          poke xPtr (fromIntegral clientX)
                          poke yPtr (fromIntegral clientY)
                          poke wPtr (fromIntegral clientW)
                          poke hPtr (fromIntegral clientH))

{# fun Fl_Tab_default_virtual_funcs as virtualFuncs' {} -> `Ptr ()' id #}

toTabWhichPrim ::
  (Ref a -> Position -> IO (Maybe (AtIndex, Ref WidgetBase))) ->
  IO (FunPtr TabWhichPrim)
toTabWhichPrim f =
  mkTabWhichPrim (\ptr event_x event_y -> do
                     pp <- wrapNonNull ptr "Null pointer. toTabWhichPrim"
                     res <- f (castTo (wrapInRef pp)) (Position (X (fromIntegral event_x)) (Y (fromIntegral event_y)))
                     maybe (return nullPtr) (\(_,ref) -> unsafeRefToPtr ref) res
                  )

customTabFunctionStruct ::
  (Parent a TabsBase) =>
  (Ref a -> IO ()) ->
  (Ref a -> IO (Maybe AtIndex, Int, [(X,Width)])) ->
  (Ref a -> IO Height) ->
  (Ref a -> Position -> IO (Maybe (AtIndex, Ref WidgetBase))) ->
  (Ref a -> IO ()) ->
  (Ref a -> TabsHeightOffset -> IO Rectangle) ->
  IO (Ptr())
customTabFunctionStruct tabDrawCustom' tabPositionsCustom' tabHeightCustom' tabWhichCustom' tabRedrawTabs' tabClientArea' =
    do
  structPtr <- virtualFuncs'
  toCallbackPrim tabDrawCustom' >>= {#set fl_Tab_Virtual_Funcs->tab_draw #} structPtr
  toTabPositionsPrim tabPositionsCustom' >>= {#set fl_Tab_Virtual_Funcs->tab_positions #} structPtr
  toTabHeightPrim tabHeightCustom' >>= {#set fl_Tab_Virtual_Funcs->tab_height #} structPtr
  toTabWhichPrim tabWhichCustom' >>= {#set fl_Tab_Virtual_Funcs->tab_which #} structPtr
  toCallbackPrim tabRedrawTabs' >>= {#set fl_Tab_Virtual_Funcs->redraw_tabs #} structPtr
  toTabClientAreaPrim tabClientArea' >>= {#set fl_Tab_Virtual_Funcs->tab_client_area #} structPtr
  return structPtr

{# fun Fl_OverriddenTabs_New_WithLabel as overriddenWidgetNewWithLabel' { `Int',`Int',`Int',`Int', `CString', id `Ptr ()', id `Ptr ()'} -> `Ptr ()' id #}
tabsCustom ::
     Rectangle                      -- ^ The bounds of this Tabs
  -> Maybe T.Text                   -- ^ The Tabs label
  -> Maybe (CustomTabFuncs Tabs)    -- ^ Optional custom tab drawing functions
  -> Maybe (CustomWidgetFuncs Tabs) -- ^ Optional custom widget functions
  -> IO (Ref Tabs)
tabsCustom rectangle l' tabFuncs' widgetFuncs' =
  let (x_pos, y_pos, width, height) = fromRectangle rectangle
  in do
   tabFuncsPtr <- maybe virtualFuncs'
                   (\tfs -> customTabFunctionStruct
                              (tabDrawCustom tfs)
                              (tabPositionsCustom tfs)
                              (tabHeightCustom tfs)
                              (tabWhichCustom tfs)
                              (tabRedrawTabs tfs)
                              (tabClientArea tfs))
                   tabFuncs'
   widgetFuncsPtr <- customWidgetFunctionStruct (fmap tabDrawCustom tabFuncs') (maybe defaultCustomWidgetFuncs id widgetFuncs')
   label' <- maybe (return nullPtr) copyTextToCString l'
   overriddenWidgetNewWithLabel' x_pos y_pos width height label' tabFuncsPtr widgetFuncsPtr >>= toRef

{# fun Fl_Tabs_New as tabsNew' { `Int',`Int',`Int',`Int' } -> `Ptr ()' id #}
{# fun Fl_Tabs_New_WithLabel as tabsNewWithLabel' { `Int',`Int',`Int',`Int',`CString'} -> `Ptr ()' id #}
tabsNew :: Rectangle -> Maybe T.Text -> IO (Ref Tabs)
tabsNew rectangle l' =
    let (x_pos, y_pos, width, height) = fromRectangle rectangle
    in case l' of
        Nothing -> tabsNew' x_pos y_pos width height >>= toRef
        Just l -> do
           ref <- copyTextToCString l >>= \l' -> tabsNewWithLabel' x_pos y_pos width height l' >>= toRef
           setFlag ref WidgetFlagCopiedLabel
           setFlag ref WidgetFlagCopiedTooltip
           return ref


{# fun Fl_Tabs_value as value' { id `Ptr ()' } -> `Ptr ()' id #}
instance (impl ~ (IO (Maybe (Ref Widget)))) => Op (GetValue ()) TabsBase orig impl where
   runOp _ _ tabs = withRef tabs $ \tabsPtr -> value' tabsPtr >>= toMaybeRef

{# fun Fl_Tabs_set_value as setValue' { id `Ptr ()',id `Ptr ()' } -> `Int' #}
instance (Parent a WidgetBase, impl ~ (Maybe ( Ref a ) ->  IO (Either NoChange ()))) => Op (SetValue ()) TabsBase orig impl where
   runOp _ _ tabs w = withRef tabs $ \tabsPtr -> withMaybeRef w $ \wPtr -> setValue' tabsPtr wPtr >>= return . successOrNoChange

{# fun Fl_Tabs_push as push' { id `Ptr ()' } -> `Ptr ()' id #}
instance (impl ~ (IO (Maybe (Ref Widget)))) => Op (GetPush ()) TabsBase orig impl where
   runOp _ _ tabs = withRef tabs $ \tabsPtr -> push' tabsPtr >>= toMaybeRef

{# fun Fl_Tabs_set_push as setPush' { id `Ptr ()',id `Ptr ()' } -> `Int' #}
instance (Parent a WidgetBase, impl ~ (Maybe ( Ref a ) ->  IO (Either NoChange ()))) => Op (SetPush ()) TabsBase orig impl where
   runOp _ _ tabs w = withRef tabs $ \tabsPtr -> withMaybeRef w $ \wPtr -> setPush' tabsPtr wPtr >>= return . successOrNoChange

{# fun Fl_Tabs_which as which' { id `Ptr ()',`Int',`Int' } -> `Ptr ()' id #}
instance (impl ~ (Position -> IO (Maybe (Ref Widget)))) => Op (Which ()) TabsBase orig impl where
   runOp _ _ tabs (Position (X event_x) (Y event_y)) = withRef tabs $ \tabsPtr -> which' tabsPtr event_x event_y >>= toMaybeRef

{# fun Fl_Tabs_client_area_with_tabh as clientAreaWithTabh' { id `Ptr ()', alloca- `Int' peekIntConv*,alloca- `Int' peekIntConv*,alloca- `Int' peekIntConv*,alloca- `Int' peekIntConv*, `Int'} -> `()' #}
instance (impl ~ (TabsHeightOffset -> IO Rectangle)) => Op (ClientArea ()) TabsBase orig impl where
   runOp _ _ tabs tabh =
     withRef tabs $ \tabsPtr ->
       clientAreaWithTabh' tabsPtr (tabsHeightOffsetToInt tabh) >>= return . toRectangle

{# fun Fl_Tabs_tab_positions as tabPositions' {id `Ptr ()'} -> `Int' #}
instance (impl ~ (IO AtIndex)) => Op (TabPositions ()) TabsBase orig impl where
  runOp _ _ tabs = withRef tabs $ \tabsPtr -> tabPositions' tabsPtr >>= return . AtIndex
{# fun Fl_Tabs_tab_height as tabHeight' {id `Ptr ()'} -> `Int' #}
instance (impl ~ (IO Height)) => Op (TabHeight ()) TabsBase orig impl where
  runOp _ _ tabs = withRef tabs $ \tabsPtr -> tabHeight' tabsPtr >>= return . Height
{# fun Fl_Tabs_get_tab_align as getTabAlign' { id `Ptr ()' } -> `AlignType' cToEnum #}
instance (impl ~ (IO (AlignType))) => Op (GetTabAlign ()) TabsBase orig impl where
   runOp _ _ tabs = withRef tabs $ \tabsPtr -> getTabAlign' tabsPtr
{# fun Fl_Tabs_set_tab_align as setTabAlign' { id `Ptr ()', cFromEnum `AlignType' } -> `()'#}
instance (impl ~ (AlignType ->  IO ())) => Op (SetTabAlign ()) TabsBase orig impl where
   runOp _ _ tabs a = withRef tabs $ \tabsPtr -> setTabAlign' tabsPtr a

{# fun Fl_Tabs_draw_super as drawSuper' { id `Ptr ()' } -> `()' supressWarningAboutRes #}
drawTabsBase ::  Ref TabsBase -> IO ()
drawTabsBase tabs = withRef tabs $ \tabsPtr -> drawSuper' tabsPtr
{# fun Fl_Tabs_handle_super as handleSuper' { id `Ptr ()',`Int' } -> `Int' #}
handleTabsBase :: Ref TabsBase -> Event ->  IO (Either UnknownEvent ())
handleTabsBase tabs event = withRef tabs $ \tabsPtr -> handleSuper' tabsPtr (fromIntegral (fromEnum event)) >>= return . successOrUnknownEvent
{# fun Fl_Tabs_resize_super as resizeSuper' { id `Ptr ()',`Int',`Int',`Int',`Int' } -> `()' supressWarningAboutRes #}
resizeTabsBase :: Ref TabsBase -> Rectangle -> IO ()
resizeTabsBase tabs rectangle =
    let (x_pos, y_pos, width, height) = fromRectangle rectangle
    in withRef tabs $ \tabsPtr -> resizeSuper' tabsPtr x_pos y_pos width height
{# fun Fl_Tabs_hide_super as hideSuper' { id `Ptr ()' } -> `()' supressWarningAboutRes #}
hideTabsBase ::  Ref TabsBase -> IO ()
hideTabsBase tabs = withRef tabs $ \tabsPtr -> hideSuper' tabsPtr
{# fun Fl_Tabs_show_super as showSuper' { id `Ptr ()' } -> `()' supressWarningAboutRes #}
showWidgetTabsBase ::  Ref TabsBase -> IO ()
showWidgetTabsBase tabs = withRef tabs $ \tabsPtr -> showSuper' tabsPtr

{# fun Fl_Tabs_draw as draw'' { id `Ptr ()' } -> `()' #}
instance (impl ~ (  IO ())) => Op (Draw ()) TabsBase orig impl where
  runOp _ _ tabs = withRef tabs $ \tabsPtr -> draw'' tabsPtr
{#fun Fl_Tabs_handle as tabsHandle' { id `Ptr ()', id `CInt' } -> `Int' #}
instance (impl ~ (Event -> IO (Either UnknownEvent ()))) => Op (Handle ()) TabsBase orig impl where
  runOp _ _ tabs event = withRef tabs (\p -> tabsHandle' p (fromIntegral . fromEnum $ event)) >>= return  . successOrUnknownEvent
{# fun Fl_Tabs_resize as resize' { id `Ptr ()',`Int',`Int',`Int',`Int' } -> `()' supressWarningAboutRes #}
instance (impl ~ (Rectangle -> IO ())) => Op (Resize ()) TabsBase orig impl where
  runOp _ _ tabs rectangle = withRef tabs $ \tabsPtr -> do
                                 let (x_pos,y_pos,w_pos,h_pos) = fromRectangle rectangle
                                 resize' tabsPtr x_pos y_pos w_pos h_pos
{# fun Fl_Tabs_hide as hide' { id `Ptr ()' } -> `()' #}
instance (impl ~ (  IO ())) => Op (Hide ()) TabsBase orig impl where
  runOp _ _ tabs = withRef tabs $ \tabsPtr -> hide' tabsPtr
{# fun Fl_Tabs_show as show' { id `Ptr ()' } -> `()' #}
instance (impl ~ (  IO ())) => Op (ShowWidget ()) TabsBase orig impl where
  runOp _ _ tabs = withRef tabs $ \tabsPtr -> show' tabsPtr

-- $hierarchy
-- @
-- "Graphics.UI.FLTK.LowLevel.Base.Widget"
--  |
--  v
-- "Graphics.UI.FLTK.LowLevel.Base.Group"
--  |
--  v
-- "Graphics.UI.FLTK.LowLevel.Base.Tabs"
-- @

-- $functions
-- @
-- clientArea :: 'Ref' 'TabsBase' -> 'TabsHeightOffset' -> 'IO' 'Rectangle'
--
-- draw :: 'Ref' 'TabsBase' -> 'IO' ()
--
-- getPush :: 'Ref' 'TabsBase' -> 'IO' ('Maybe' ('Ref' 'Widget'))
--
-- getTabAlign :: 'Ref' 'TabsBase' -> 'IO' ('AlignType')
--
-- getValue :: 'Ref' 'TabsBase' -> 'IO' ('Maybe' ('Ref' 'Widget'))
--
-- handle :: 'Ref' 'TabsBase' -> 'Event' -> 'IO' ('Either' 'UnknownEvent' ())
--
-- hide :: 'Ref' 'TabsBase' -> 'IO' ()
--
-- resize :: 'Ref' 'TabsBase' -> 'Rectangle' -> 'IO' ()
--
-- setPush:: ('Parent' a 'WidgetBase') => 'Ref' 'TabsBase' -> 'Maybe' ( 'Ref' a ) -> 'IO' ('Either' 'NoChange' ())
--
-- setTabAlign :: 'Ref' 'TabsBase' -> 'AlignType' -> 'IO' ()
--
-- setValue:: ('Parent' a 'WidgetBase') => 'Ref' 'TabsBase' -> 'Maybe' ( 'Ref' a ) -> 'IO' ('Either' 'NoChange' ())
--
-- showWidget :: 'Ref' 'TabsBase' -> 'IO' ()
--
-- tabHeight :: 'Ref' 'TabsBase' -> 'IO' 'Height'
--
-- tabPositions :: 'Ref' 'TabsBase' -> 'IO' 'AtIndex'
--
-- which :: 'Ref' 'TabsBase' -> 'Position' -> 'IO' ('Maybe' ('Ref' 'Widget'))
-- @
