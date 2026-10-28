{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wincomplete-patterns #-}
{-# OPTIONS_GHC -Wunused-imports #-}

module Parser (Err, closed, norm, validate) where

import Data.Aeson (Value (..))
import Data.Aeson.Key qualified as K
import Data.Aeson.KeyMap qualified as KM
import Data.Bifunctor (first)
import Data.Map.Strict qualified as M
import Data.Text qualified as T
import Schema (Schema (..))

-- | (エラー位置のキー列, メッセージ)
type Err = ([T.Text], T.Text)

-- $setup
-- >>> :set -XOverloadedStrings

-- | Springのrelaxed bindingの近似: 小文字化し'-'と'_'を除去
--
-- >>> norm "driver-class-name"
-- "driverclassname"
-- >>> norm "driverClassName"
-- "driverclassname"
-- >>> norm "DRIVER_CLASS_NAME"
-- "driverclassname"
norm :: T.Text -> T.Text
norm txt = T.toLower . T.filter (`notElem` ("-_" :: String)) $ txt

-- | rulesを書くためのヘルパー
-- キーはnormで正規化する。正規化後に同じになるキーが複数あるときは、後に書いた方が優先される
closed :: [(T.Text, Schema)] -> Schema
closed = Closed . M.fromList . map (first norm)

-- | validater
validate :: [T.Text] -> Schema -> Value -> [Err]
validate path sch v = case (sch, v) of
  (Open, _) -> [] -- チェックしない部分
  -- fs: 今いる位置の子として許されるものの一覧をMapで持つ
  (Closed fs, Object o) -> concatMap field (KM.toList o)
    where
      field (k, x) = case T.splitOn "." (K.toText k) of
        -- `server..port`、`server.`、`.server`のように空の区間を含むドット記法は、展開せずにエラーにする
        segs | any T.null segs -> [(path ++ [K.toText k], "invalid dotted key: empty segment")]
        (k1 : rest) -> check k1 $ foldr nest x rest
        [] -> []
      -- \| nest の役割は、「キー1つと値1つを、1要素の Object で包む」ことです。
      -- キーが3段以上の場合 (a.b.c: x)
      -- rest = ["b", "c"]
      -- foldr nest x ["b", "c"]
      -- = nest "b" (nest "c" x)
      -- = nest "b" {c: x}
      -- = {b: {c: x}}
      nest k acc = Object (KM.singleton (K.fromText k) acc)
      check k x = case M.lookup (norm k) fs of
        Just s -> validate (path ++ [k]) s x
        Nothing ->
          [ ( path ++ [k],
              "unknown key. allowed: " <> T.intercalate ", " (M.keys fs)
            )
          ]
  -- MapOf 配下ではドットもキーの一部（logging.level.com.example など）
  (MapOf s, Object o) ->
    concat [validate (path ++ [K.toText k]) s x | (k, x) <- KM.toList o]
  -- 子キーを持つべき位置に値が直接書かれている(例: `datasource: foo`)
  -- `_`でまとめると、Schemaにコンストラクタを足しても網羅性の警告が出ないため明示する
  (Closed _, _) -> [(path, "expected nested keys")]
  (MapOf _, _) -> [(path, "expected nested keys")]
