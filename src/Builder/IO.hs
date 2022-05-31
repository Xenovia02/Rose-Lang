module Builder.IO (
    writeBin,
    message,
    status,
    debug,
    warn,
    fatal,
    traceFile,
    trace',
    trace,
) where

import Data.Binary (Binary, encodeFile)
import System.Exit (exitFailure)
import System.Directory (createDirectoryIfMissing)

import Builder.Internal
import Cmd
import Common.Module
import Text.Pretty


message, status, debug :: Pretty a => a -> Builder ()
message = myPutStr 1 . terse
status = myPutStr 2 . pretty
debug = myPutStr 3 . detailed

warn :: String -> Builder ()
warn str = do
    wError ?!> fatal str
    myPutStr 1 str

fatal :: String -> Builder a
fatal str = do
    myPutStr 0 str
    io $ putChar '\n'
    io exitFailure

writeBin :: Binary a => String -> a -> Builder ()
writeBin [] _ = fail "writeBin: empty input string"
writeBin ext a = do
    bin <- getBinDir
    name <- gets moduleName
    let !dir = bin ++ modToDir name
        !path = dir ++ modEndpoint name ++ ext
    io (createDirectoryIfMissing True dir)
    io (encodeFile path a)
    return ()

trace' :: Pretty a => a -> Builder ()
trace' = io . putStrLn . ("~~| "*|)

trace :: Pretty a => a -> Builder ()
trace a = cmdTrace ??> io (putStrLn ("~~| "*|a))

traceFile :: Pretty a => FilePath -> a -> Builder ()
traceFile path a = cmdTrace ??> do
    dir <- getCurrTraceDir
    let str = uncolor (processString (detailed a))
    io (writeFile (dir ++ path ++ ".trace") str)

myPutStr :: Int -> String -> Builder ()
myPutStr thresh str = ((thresh <=).verbosity) ??> io
    (putStr (processString str))
