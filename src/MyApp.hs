{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wunused-imports #-}

-- | 純粋なロジックを置くライブラリモジュール。IO は app/Main.hs 側に寄せる。
module MyApp (greet) where

import Data.Text (Text)
import Data.Text qualified as Text

-- | 名前を受け取って挨拶文を返す。空白だけの名前は "World" として扱う。
greet :: Text -> Text
greet name = "Hello, " <> target <> "!"
  where
    stripped :: Text
    stripped = Text.strip name

    target :: Text
    target = if Text.null stripped then "World" else stripped
