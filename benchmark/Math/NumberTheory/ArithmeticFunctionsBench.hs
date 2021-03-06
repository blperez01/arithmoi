module Math.NumberTheory.ArithmeticFunctionsBench
  ( benchSuite
  ) where

import Criterion.Main
import Data.Set (Set)

import Math.NumberTheory.ArithmeticFunctions as A

compareFunctions :: String -> (Integer -> Integer) -> Benchmark
compareFunctions name new = bench name $ nf (map new) [1..100000]

compareSetFunctions :: String -> (Integer -> Set Integer) -> Benchmark
compareSetFunctions name new = bench name $ nf (map new) [1..100000]

benchSuite = bgroup "ArithmeticFunctions"
  [ compareSetFunctions "divisors" A.divisors
  , bench "divisors/int" $ nf (map A.divisorsSmall) [1 :: Int .. 100000]
  , compareFunctions "totient" A.totient
  , compareFunctions "carmichael" A.carmichael
  , compareFunctions "moebius" A.moebius
  , compareFunctions "tau" A.tau
  , compareFunctions "sigma 1" (A.sigma 1)
  , compareFunctions "sigma 2" (A.sigma 2)
  ]
