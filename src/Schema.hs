{-# OPTIONS_GHC -Wunused-imports #-}

module Schema (Schema (..)) where

import Data.Map.Strict qualified as M
import Data.Text qualified as T

-- | キーの構造
data Schema
  = Closed (M.Map T.Text Schema) -- 列挙したキーだけ許可
  | MapOf Schema -- キー名は検査しないが、valueの値は検査したい時
  | Open -- 中身は検査しない(葉もこれで表す)
