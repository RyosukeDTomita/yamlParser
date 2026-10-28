{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wunused-imports #-}

module Main (main) where

import Data.Aeson (Value)
import Data.Text qualified as T
import Data.Yaml qualified as Y
import Parser qualified as P
import Rules (rules)

main :: IO ()
main = do
  -- r <- Y.decodeAllFileEither "application.yaml.example1"
  r <- Y.decodeAllFileEither "application.yaml.example2"
  case r of
    Left e -> print e
    Right docs ->
      mapM_
        (\(p, m) -> putStrLn (T.unpack (T.intercalate "." p <> ": " <> m)))
        (concatMap (P.validate [] rules) (docs :: [Value]))
