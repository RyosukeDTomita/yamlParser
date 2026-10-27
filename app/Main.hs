{-# OPTIONS_GHC -Wunused-imports #-}

module Main (main) where

import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import MyApp (greet)
import System.Environment (getArgs)

main :: IO ()
main = do
  args <- getArgs
  TextIO.putStrLn $ greet $ Text.pack $ unwords args
