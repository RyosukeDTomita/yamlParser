{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wunused-imports #-}

import Data.Aeson (Value (..), object, toJSON, (.=))
import Data.Text qualified as T
import Parser (Err, closed, validate)
import Rules (rules)
import Schema (Schema (..))
import Test.Hspec

-- | エラーの位置だけを取り出す(メッセージは比較しない)
errPaths :: [Err] -> [[T.Text]]
errPaths errs = [p | (p, _) <- errs]

str :: T.Text -> Value
str t = String t

-- | validateの各分岐を確かめるための小さなスキーマ
schema :: Schema
schema =
  closed
    [ ("server", closed [("port", Open)]),
      ("driver-class-name", Open),
      ("level", MapOf Open),
      ("endpoint", MapOf $ closed [("enabled", Open)]),
      ("hikari", Open)
    ]

-- | 子キーを持つべき位置に置く、Object以外の値
nonObjects :: [(String, Value)]
nonObjects =
  [ ("String", str "foo"),
    ("Number", Number 1),
    ("Bool", Bool True),
    ("Null", Null),
    ("Array", toJSON [1 :: Int, 2])
  ]

main :: IO ()
main = hspec $ do
  describe "validate: (Open, _)" $ do
    it "accepts any scalar" $
      concatMap (\(_, v) -> validate [] Open v) nonObjects `shouldBe` []

    it "accepts any nested object without checking keys" $
      let doc = object ["anything" .= object ["goes" .= str "here"]]
       in validate [] Open doc `shouldBe` []

    it "stops checking below an Open key" $
      let doc = object ["hikari" .= object ["maximum-pool-size" .= (10 :: Int), "unknown" .= str "x"]]
       in validate [] schema doc `shouldBe` []

  describe "validate: (Closed, Object)" $ do
    it "accepts an empty object" $
      validate [] schema (object []) `shouldBe` []

    it "accepts a listed key" $
      let doc = object ["server" .= object ["port" .= (8080 :: Int)]]
       in validate [] schema doc `shouldBe` []

    it "reports an unlisted key" $
      errPaths (validate [] schema $ object ["sever" .= object []]) `shouldBe` [["sever"]]

    it "reports an unlisted key at a nested position" $
      let doc = object ["server" .= object ["prot" .= (8080 :: Int)]]
       in errPaths (validate [] schema doc) `shouldBe` [["server", "prot"]]

    it "collects every unlisted key" $
      let doc = object ["foo" .= str "x", "server" .= object ["bar" .= str "y"]]
       in errPaths (validate [] schema doc) `shouldMatchList` [["foo"], ["server", "bar"]]

    it "matches keys by relaxed binding (case, '-' and '_')" $
      let doc =
            object
              [ "driverClassName" .= str "a",
                "DRIVER_CLASS_NAME" .= str "b",
                "Server" .= object ["PORT" .= (1 :: Int)]
              ]
       in validate [] schema doc `shouldBe` []

    it "expands a dotted key into nested keys" $
      let doc = object ["server.port" .= (8080 :: Int)]
       in validate [] schema doc `shouldBe` []

    it "reports the segment of a dotted key that is unlisted" $
      let doc = object ["server.prot" .= (8080 :: Int), "srv.port" .= (8080 :: Int)]
       in errPaths (validate [] schema doc) `shouldMatchList` [["server", "prot"], ["srv"]]

    it "rejects a dotted key with an empty segment without expanding it" $
      let doc = object ["server..port" .= (1 :: Int), "server." .= (1 :: Int), ".server" .= (1 :: Int)]
       in errPaths (validate [] schema doc) `shouldMatchList` [["server..port"], ["server."], [".server"]]

    it "prepends the given path to error paths" $
      errPaths (validate ["root"] schema $ object ["foo" .= str "x"]) `shouldBe` [["root", "foo"]]

  describe "validate: (MapOf, Object)" $ do
    it "accepts an empty object" $
      validate [] schema (object ["level" .= object []]) `shouldBe` []

    it "accepts any child key names" $
      let doc = object ["level" .= object ["root" .= str "INFO", "anything" .= str "DEBUG"]]
       in validate [] schema doc `shouldBe` []

    it "keeps a dotted child key as one key" $
      let doc = object ["endpoint" .= object ["a.b" .= object ["typo" .= True]]]
       in errPaths (validate [] schema doc) `shouldBe` [["endpoint", "a.b", "typo"]]

    it "accepts a child key with an empty dotted segment (MapOf does not split dots)" $
      validate [] schema (object ["level" .= object ["a..b" .= str "INFO"]]) `shouldBe` []

    it "checks every child with the same schema" $
      let doc =
            object
              [ "endpoint"
                  .= object
                    [ "health" .= object ["enabled" .= True],
                      "info" .= object ["enabld" .= True],
                      "prometheus" .= object ["foo" .= True]
                    ]
              ]
       in errPaths (validate [] schema doc)
            `shouldMatchList` [["endpoint", "info", "enabld"], ["endpoint", "prometheus", "foo"]]

  describe "validate: (Closed, non-Object)" $
    mapM_
      ( \(name, v) ->
          it ("reports " <> name <> " where nested keys are expected") $
            errPaths (validate [] schema $ object ["server" .= v]) `shouldBe` [["server"]]
      )
      nonObjects

  describe "validate: (MapOf, non-Object)" $
    mapM_
      ( \(name, v) ->
          it ("reports " <> name <> " where nested keys are expected") $
            errPaths (validate [] schema $ object ["level" .= v]) `shouldBe` [["level"]]
      )
      nonObjects

  describe "validate with rules" $ do
    it "returns no errors for keys allowed by the rules" $
      let doc =
            object
              [ "spring"
                  .= object
                    ["datasource" .= object ["driver-class-name" .= ("org.postgresql.Driver" :: T.Text)]],
                "server.port" .= (8080 :: Int)
              ]
       in errPaths (validate [] rules doc) `shouldBe` []

    it "reports the path of an unknown key" $
      let doc =
            object
              ["spring" .= object ["datasource" .= object ["pasword" .= ("secret" :: T.Text)]]]
       in errPaths (validate [] rules doc) `shouldBe` [["spring", "datasource", "pasword"]]

  describe "closed" $
    it "keeps the later schema when keys collide after norm" $
      -- "a-b"と"ab"はnormでどちらも"ab"になる。後に書いたclosed [](子キーを許可しない)が残る
      let dup = closed [("a-b", Open), ("ab", closed [])]
       in errPaths (validate [] dup $ object ["a-b" .= object ["x" .= True]]) `shouldBe` [["a-b", "x"]]

  -- 既知のバグ。直したらこのテストは失敗するので、正しい期待値に書き換える
  describe "known bugs" $
    it "BUG: splits a dot inside a MapOf child name when the parent key uses dot notation" $
      -- 本来は"a.b"を1つのendpoint名として扱い、エラーは0件になるべき。
      -- 実際はClosed側でドット記法を展開するときに"a"と"b"に分解され、"b"がunknown keyになる
      let doc = object ["endpoint.a.b.enabled" .= True]
       in errPaths (validate [] schema doc) `shouldBe` [["endpoint", "a", "b"]]
