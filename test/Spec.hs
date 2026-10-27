{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wunused-imports #-}

import MyApp (greet)
import Test.Hspec

main :: IO ()
main = hspec $ do
  describe "greet" $ do
    it "greets the given name" $
      greet "Haskell" `shouldBe` "Hello, Haskell!"

    it "strips surrounding whitespace" $
      greet "  Haskell  " `shouldBe` "Hello, Haskell!"

    it "falls back to World for a blank name" $
      greet "   " `shouldBe` "Hello, World!"
