module Builder.State where

import Data.Text (Text, empty)

import CmdLine


type Stream = Text

data State = State {
        stCmdLine :: {-# UNPACK #-} !CmdLine,
        stFile :: !FilePath,
        stModule :: !String,
        -- current build directory, as opposed to
        -- cmdBuildDir, which is the base
        stBuildDir :: !FilePath,
        stSource :: Text
    }


mkState :: CmdLine -> State
{-# INLINE mkState #-}
mkState cmd = State cmd [] [] [] empty