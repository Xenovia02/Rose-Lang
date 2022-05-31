{-# LANGUAGE LambdaCase #-}

module Repl (runRepl) where

import Data.Binary (decodeFile)
import Data.ByteString.Lazy.Char8 (pack)
import Data.List (isPrefixOf)
import Control.Monad (foldM)
import Control.Monad.IO.Class
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Reader
import Control.Monad.Trans.State
import System.Console.Repline
import System.Directory (doesFileExist)
import System.IO

import Analysis.Error
import Cmd
import Common.Module
import Data.Table
import qualified Data.VarMap as M
import Parser.Parser (runAlex, replP)
import Typing.Inferable
import Text.Pretty


type ReplMonad = StateT Table (ReaderT CmdLine IO)
type Repl = HaskelineT ReplMonad


printM :: (MonadIO m, Pretty a) => a -> m ()
printM = liftIO . putStrLn . uncolor . processString . pretty

replOpts :: ReplOpts ReplMonad
replOpts = ReplOpts {
    banner = \case
        SingleLine -> return ">>| "
        MultiLine -> return "+ | ",
    command = typeOf, -- TEMP
    options = [
        ("t", typeOf),
        ("type", typeOf),
        ("l", load),
        ("load", load),
        ("b", browse),
        ("browse", browse),
        ("q", const abort),
        ("quit", const abort)
        ],
    prefix = Just ':',
    multilineCommand = Nothing,
    tabComplete = Combine (Word0 completer) File,
    initialiser = load "Std.Prelude",
    finaliser = return Exit
    }

completer :: WordCompleter ReplMonad
completer = go . reverse
    where
        go str = do
            let cmds = (':':) . fst
                    <$> options replOpts
                opts = filter (str `isPrefixOf`) cmds
            return opts

typeOf :: Cmd Repl
typeOf str = case runAlex (pack str) replP of
    Left err -> printM ("<stdin>"+|err)
    Right val -> do
        table <- lift get
        case makeInference table (infer val) of
            Left errs -> printM $ concatMap (\err ->
                "<stdin>"+|(ErrMsg (lines (tail str)) err)
                ) errs
            Right scheme -> printM scheme

browse :: Cmd Repl
browse _ = do
    table <- lift get
    let types = dataType <$> M.elems (tblTypes table)
        glbs = M.assocs (tblGlobals table)
    mapM_ (printM . ("data "+|)) types
    mapM_ (\(k,v) -> printM (k|+" :: "*|funcType v)) glbs

load :: Cmd Repl
load str = do
    let mods = strToMod <$> words str
    tbl <- lift get
    tbl' <- foldM (\prev mdl -> do
        let file = "Rose-Build/bin/"++modToContFile mdl ".o"
        exists <- liftIO (doesFileExist file)
        if exists then do
            table <- liftIO (decodeFile file)
            return $! unionTable prev table
        else do
            printM ("Could not find module: "+|mdl)
            return prev
        ) tbl mods
    lift (put tbl')
    return ()

runRepl :: CmdLine -> IO ()
runRepl cmd = do
    hSetEcho stderr False
    hSetEcho stdout False
    let opts = evalReplOpts replOpts
    let st = evalStateT opts emptyTable
    runReaderT st cmd
