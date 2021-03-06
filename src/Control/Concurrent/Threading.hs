{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE LambdaCase #-}

module Threading (
    Manager,
    Status(..),
    ExitCode(..),
    newManager,
    fork,
    threadStatus,
    exitSelf,
    wait, waitAll,
) where

import Control.Concurrent
import Control.Exception (
        IOException,
        throwIO,
        try
    )
import Control.Monad ((<$!>), join)
import qualified Data.Map as Map
import System.Exit (ExitCode(..))


default (Int, Double)


data Status
    = Running
    | Finished
    | Threw IOException
    deriving (Show)

newtype Manager = Mgr (MVar (Map.Map ThreadId (MVar Status)))


newManager :: IO Manager
newManager = Mgr <$!> (newMVar $! Map.empty)

fork :: Manager -> IO () -> IO ThreadId
fork (Mgr mgr) f = modifyMVar mgr $ \m -> do
    st <- newEmptyMVar
    thrID <- forkIO $ do
        res <- try f
        putMVar st (either Threw (const Finished) res)
    return (Map.insert thrID st m, thrID)

threadStatus :: Manager -> ThreadId -> IO (Maybe Status)
threadStatus (Mgr mgr) thrID = modifyMVar mgr $ \m ->
    case Map.lookup thrID m of
        Nothing -> return (m, Nothing)
        Just st -> tryTakeMVar st >>= \case
            Nothing -> return (m, Just Running)
            Just sth -> return (Map.delete thrID m, Just sth)

exitSelf :: ExitCode -> IO a
exitSelf = throwIO

wait :: Manager -> ThreadId -> IO (Maybe Status)
wait (Mgr mgr) thrID = join $! modifyMVar mgr $ \m -> return $!
    (case Map.updateLookupWithKey (\_ _ -> Nothing) thrID m of
        (Nothing, _) -> (m, return Nothing)
        (Just st, m') -> (m', Just <$!> takeMVar st))

waitAll :: Manager -> IO ()
waitAll (Mgr mgr) = do
    elems <- modifyMVar mgr $
        \m -> return (Map.empty, Map.elems m)
    mapM_ takeMVar elems
