-- |
-- Module:      Math.NumberTheory.Recurrencies.BilinearTests
-- Copyright:   (c) 2016 Andrew Lelechenko
-- Licence:     MIT
-- Maintainer:  Andrew Lelechenko <andrew.lelechenko@gmail.com>
-- Stability:   Provisional
--
-- Tests for Math.NumberTheory.Recurrencies.Bilinear
--

{-# OPTIONS_GHC -fno-warn-type-defaults #-}

module Math.NumberTheory.Recurrencies.BilinearTests
  ( testSuite
  ) where

import Test.Tasty
import Test.Tasty.HUnit

import Data.Ratio

import Math.NumberTheory.Recurrencies.Bilinear
import Math.NumberTheory.TestUtils

binomialProperty1 :: NonNegative Int -> Bool
binomialProperty1 (NonNegative i) = length (binomial !! i) == i + 1

binomialProperty2 :: NonNegative Int -> Bool
binomialProperty2 (NonNegative i) = binomial !! i !! 0 == 1

binomialProperty3 :: NonNegative Int -> Bool
binomialProperty3 (NonNegative i) = binomial !! i !! i == 1

binomialProperty4 :: Positive Int -> Positive Int -> Bool
binomialProperty4 (Positive i) (Positive j)
  =  j >= i
  || binomial !! i !! j
  == binomial !! (i - 1) !! (j - 1)
  +  binomial !! (i - 1) !! j

stirling1Property1 :: NonNegative Int -> Bool
stirling1Property1 (NonNegative i) = length (stirling1 !! i) == i + 1

stirling1Property2 :: NonNegative Int -> Bool
stirling1Property2 (NonNegative i)
  =  stirling1 !! i !! 0
  == if i == 0 then 1 else 0

stirling1Property3 :: NonNegative Int -> Bool
stirling1Property3 (NonNegative i) = stirling1 !! i !! i == 1

stirling1Property4 :: Positive Int -> Positive Int -> Bool
stirling1Property4 (Positive i) (Positive j)
  =  j >= i
  || stirling1 !! i !! j
  == stirling1 !! (i - 1) !! (j - 1)
  +  (toInteger i - 1) * stirling1 !! (i - 1) !! j

stirling2Property1 :: NonNegative Int -> Bool
stirling2Property1 (NonNegative i) = length (stirling2 !! i) == i + 1

stirling2Property2 :: NonNegative Int -> Bool
stirling2Property2 (NonNegative i)
  =  stirling2 !! i !! 0
  == if i == 0 then 1 else 0

stirling2Property3 :: NonNegative Int -> Bool
stirling2Property3 (NonNegative i) = stirling2 !! i !! i == 1

stirling2Property4 :: Positive Int -> Positive Int -> Bool
stirling2Property4 (Positive i) (Positive j)
  =  j >= i
  || stirling2 !! i !! j
  == stirling2 !! (i - 1) !! (j - 1)
  +  toInteger j * stirling2 !! (i - 1) !! j

lahProperty1 :: NonNegative Int -> Bool
lahProperty1 (NonNegative i) = length (lah !! i) == i + 1

lahProperty2 :: NonNegative Int -> Bool
lahProperty2 (NonNegative i)
  =  lah !! i !! 0
  == product [1 .. i+1]

lahProperty3 :: NonNegative Int -> Bool
lahProperty3 (NonNegative i) = lah !! i !! i == 1

lahProperty4 :: Positive Int -> Positive Int -> Bool
lahProperty4 (Positive i) (Positive j)
  =  j >= i
  || lah !! i !! j
  == sum [ stirling1 !! (i + 1) !! k * stirling2 !! k !! (j + 1) | k <- [j + 1 .. i + 1] ]

eulerian1Property1 :: NonNegative Int -> Bool
eulerian1Property1 (NonNegative i) = length (eulerian1 !! i) == i

eulerian1Property2 :: Positive Int -> Bool
eulerian1Property2 (Positive i) = eulerian1 !! i !! 0 == 1

eulerian1Property3 :: Positive Int -> Bool
eulerian1Property3 (Positive i) = eulerian1 !! i !! (i - 1) == 1

eulerian1Property4 :: Positive Int -> Positive Int -> Bool
eulerian1Property4 (Positive i) (Positive j)
  =  j >= i - 1
  || eulerian1 !! i !! j
  == (toInteger $ i - j) * eulerian1 !! (i - 1) !! (j - 1)
  +  (toInteger   j + 1) * eulerian1 !! (i - 1) !! j

eulerian2Property1 :: NonNegative Int -> Bool
eulerian2Property1 (NonNegative i) = length (eulerian2 !! i) == i

eulerian2Property2 :: Positive Int -> Bool
eulerian2Property2 (Positive i)
  =  eulerian2 !! i !! 0 == 1

eulerian2Property3 :: Positive Int -> Bool
eulerian2Property3 (Positive i)
  =  eulerian2 !! i !! (i - 1)
  == product [1 .. toInteger i]

eulerian2Property4 :: Positive Int -> Positive Int -> Bool
eulerian2Property4 (Positive i) (Positive j)
  =  j >= i - 1
  || eulerian2 !! i !! j
  == (toInteger $ 2 * i - j - 1) * eulerian2 !! (i - 1) !! (j - 1)
  +  (toInteger j + 1) * eulerian2 !! (i - 1) !! j

bernoulliSpecialCase1 :: Assertion
bernoulliSpecialCase1 = assertEqual "B_0 = 1" (bernoulli !! 0) 1

bernoulliSpecialCase2 :: Assertion
bernoulliSpecialCase2 = assertEqual "B_1 = -1/2" (bernoulli !! 1) (- 1 % 2)

bernoulliProperty1 :: NonNegative Int -> Bool
bernoulliProperty1 (NonNegative m)
  = case signum (bernoulli !! m) of
    1  -> m == 0 || m `mod` 4 == 2
    0  -> m /= 1 && odd m
    -1 -> m == 1 || (m /= 0 && m `mod` 4 == 0)
    _  -> False

bernoulliProperty2 :: NonNegative Int -> Bool
bernoulliProperty2 (NonNegative m)
  =  bernoulli !! m
  == (if m == 0 then 1 else 0)
  -  sum [ bernoulli !! k
         * (binomial !! m !! k % (toInteger $ m - k + 1))
         | k <- [0 .. m - 1]
         ]

assertEqualUpToEps :: String -> Double -> Double -> Double -> Assertion
assertEqualUpToEps msg eps expected actual
  = assertBool msg (abs (expected - actual) < eps)

epsilon :: Double
epsilon = 1e-15

zetaEvenSpecialCase1 :: Assertion
zetaEvenSpecialCase1
  = assertEqual "zeta(0) = -1/2"
    (approximateValue $ zetaEven !! 0)
    (-1 / 2)

zetaEvenSpecialCase2 :: Assertion
zetaEvenSpecialCase2
  = assertEqualUpToEps "zeta(2) = pi^2/6" epsilon
    (approximateValue $ zetaEven !! 1)
    (pi * pi / 6)

zetaEvenSpecialCase3 :: Assertion
zetaEvenSpecialCase3
  = assertEqualUpToEps "zeta(4) = pi^4/90" epsilon
    (approximateValue $ zetaEven !! 2)
    (pi ^ 4 / 90)

zetaEvenProperty1 :: Positive Int -> Bool
zetaEvenProperty1 (Positive m)
  =  zetaM < 1
  || zetaM > zetaM1
  where
    zetaM  = approximateValue (zetaEven !! m)
    zetaM1 = approximateValue (zetaEven !! (m + 1))

zetaOdd' :: [Double]
zetaOdd' = zetaOdd epsilon

zetaOddSpecialCase1 :: Assertion
zetaOddSpecialCase1
  = assertEqual "zeta(1) = Infinity"
    (zetaOdd' !! 0)
    (1 / 0)

zetaOddSpecialCase2 :: Assertion
zetaOddSpecialCase2
  = assertEqualUpToEps "zeta(3) = 1.2020569" 1e-15
    (zetaOdd' !! 1)
    1.2020569031595942853997381615114499908

zetaOddSpecialCase3 :: Assertion
zetaOddSpecialCase3
  = assertEqualUpToEps "zeta(5) = 1.0369277" 1e-15
    (zetaOdd' !! 2)
    1.0369277551433699263313654864570341681

zetaOddProperty1 :: Positive Int -> Bool
zetaOddProperty1 (Positive m)
  =  zetaM < 1
  || zetaM > zetaM1
  where
    zetaM  = zetaOdd' !! m
    zetaM1 = zetaOdd' !! (m + 1)

zetaProperty1 :: Positive Int -> Bool
zetaProperty1 (Positive m)
  =  zetaM < 1
  || zetaM > zetaM1
  where
    zetaM  = approximateValue (zetaEven !! m)
    zetaM1 = zetaOdd' !! m

zetaProperty2 :: NonNegative Int -> Bool
zetaProperty2 (NonNegative m)
  =  zetaM < 1
  || zetaM > zetaM1
  where
    zetaM  = zetaOdd' !! m
    zetaM1 = approximateValue (zetaEven !! (m + 1))

testSuite :: TestTree
testSuite = testGroup "Bilinear"
  [ testGroup "binomial"
    [ testSmallAndQuick "shape"      binomialProperty1
    , testSmallAndQuick "left side"  binomialProperty2
    , testSmallAndQuick "right side" binomialProperty3
    , testSmallAndQuick "recurrency" binomialProperty4
    ]
  , testGroup "stirling1"
    [ testSmallAndQuick "shape"      stirling1Property1
    , testSmallAndQuick "left side"  stirling1Property2
    , testSmallAndQuick "right side" stirling1Property3
    , testSmallAndQuick "recurrency" stirling1Property4
    ]
  , testGroup "stirling2"
    [ testSmallAndQuick "shape"      stirling2Property1
    , testSmallAndQuick "left side"  stirling2Property2
    , testSmallAndQuick "right side" stirling2Property3
    , testSmallAndQuick "recurrency" stirling2Property4
    ]
  , testGroup "lah"
    [ testSmallAndQuick "shape"         lahProperty1
    , testSmallAndQuick "left side"     lahProperty2
    , testSmallAndQuick "right side"    lahProperty3
    , testSmallAndQuick "zip stirlings" lahProperty4
    ]
  , testGroup "eulerian1"
    [ testSmallAndQuick "shape"      eulerian1Property1
    , testSmallAndQuick "left side"  eulerian1Property2
    , testSmallAndQuick "right side" eulerian1Property3
    , testSmallAndQuick "recurrency" eulerian1Property4
    ]
  , testGroup "eulerian2"
    [ testSmallAndQuick "shape"      eulerian2Property1
    , testSmallAndQuick "left side"  eulerian2Property2
    , testSmallAndQuick "right side" eulerian2Property3
    , testSmallAndQuick "recurrency" eulerian2Property4
    ]
  , testGroup "bernoulli"
    [ testCase "B_0"                           bernoulliSpecialCase1
    , testCase "B_1"                           bernoulliSpecialCase2
    , testSmallAndQuick "sign"                 bernoulliProperty1
    , testSmallAndQuick "recursive definition" bernoulliProperty2
    ]
  , testGroup "zeta"
    [ testCase "zeta(0)"                          zetaEvenSpecialCase1
    , testCase "zeta(2)"                          zetaEvenSpecialCase2
    , testCase "zeta(4)"                          zetaEvenSpecialCase3
    , testSmallAndQuick "zeta(2n) > zeta(2n+2)"   zetaEvenProperty1
    , testCase "zeta(1)"                          zetaOddSpecialCase1
    , testCase "zeta(3)"                          zetaOddSpecialCase2
    , testCase "zeta(5)"                          zetaOddSpecialCase3
    , testSmallAndQuick "zeta(2n+1) > zeta(2n+3)" zetaOddProperty1
    , testSmallAndQuick "zeta(2n) > zeta(2n+1)"   zetaProperty1
    , testSmallAndQuick "zeta(2n+1) > zeta(2n+2)" zetaProperty2
    ]
  ]
