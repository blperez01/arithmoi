-- |
-- Module:          Math.NumberTheory.Primes.Sieve.Eratosthenes
-- Copyright:   (c) 2011 Daniel Fischer
-- Licence:     MIT
-- Maintainer:  Daniel Fischer <daniel.is.fischer@googlemail.com>
-- Stability:   Provisional
-- Portability: Non-portable (GHC extensions)
--
-- Sieve
--
{-# LANGUAGE CPP, BangPatterns, ScopedTypeVariables #-}
module Math.NumberTheory.Primes.Sieve.Eratosthenes
    ( primes
    , sieveFrom
    , PrimeSieve(..)
    , primeList
    , primeSieve
    , nthPrime
    , factorSieve
    , totientSieve
    , carmichaelSieve
    ) where

#include "MachDeps.h"

import Control.Monad.ST
import Data.Array.Base (unsafeRead, unsafeWrite, unsafeAt, unsafeNewArray_)
import Data.Array.ST
import Data.Array.Unboxed
import Control.Monad (when)
import Data.Bits
import Data.Word

import Math.NumberTheory.Powers.Squares (integerSquareRoot)
import Math.NumberTheory.Utils
import Math.NumberTheory.Primes.Counting.Approximate
-- import Math.NumberTheory.Primes.Sieve.Types

-- Sieve in 128K chunks.
-- Large enough to get something done per chunk
-- and hopefully small enough to fit in the cache.
sieveBytes :: Int
sieveBytes = 128*1024

-- Number of bits per chunk.
sieveBits :: Int
sieveBits = 8*sieveBytes

-- Last index of chunk.
lastIndex :: Int
lastIndex = sieveBits - 1

-- Range of a chunk.
sieveRange :: Int
sieveRange = 30*sieveBytes

sieveWords :: Int
sieveWords = sieveBytes `quot` SIZEOF_HSWORD

#if SIZEOF_HSWORD == 8
type CacheWord = Word
#define RMASK 63
#define WSHFT 6
#define TOPB 32
#define TOPM 0xFFFFFFFF
#else
type CacheWord = Word64
#define RMASK 31
#define WSHFT 5
#define TOPB 16
#define TOPM 0xFFFF
#endif

data PrimeSieve = PS !Integer {-# UNPACK #-} !(UArray Int Bool)

data FactorSieve = FS {-# UNPACK #-} !Int {-# UNPACK #-} !(UArray Int Int)

data TotientSieve = TS {-# UNPACK #-} !Int {-# UNPACK #-} !(UArray Int Int)

data CarmichaelSieve = CS {-# UNPACK #-} !Int {-# UNPACK #-} !(UArray Int Int)

primeSieve :: Integer -> PrimeSieve
primeSieve bound = PS 0 (runSTUArray $ sieveTo bound)

factorSieve :: Integer -> FactorSieve
factorSieve bound
  | fromIntegral (maxBound :: Int) < bound  = error "factorSieve: would overflow"
  | bound < 2   = error "factorSieve: bound must be at least 2"
  | bound < 7   = FS bnd (array (0,0) [(0,0)])
  | otherwise   = FS bnd (runSTUArray (spfSieve bnd))
    where
      bnd = fromInteger bound

totientSieve :: Integer -> TotientSieve
totientSieve bound
  | fromIntegral (maxBound :: Int) < bound  = error "totientSieve: would overflow"
  | bound < 2   = error "totientSieve: bound must be at least 2"
  | bound < 7   = TS bnd (array (0,0) [(0,0)])
  | otherwise   = TS bnd (totSieve bnd)
    where
      bnd = fromInteger bound

carmichaelSieve :: Integer -> CarmichaelSieve
carmichaelSieve bound
  | fromIntegral (maxBound :: Int) < bound  = error "carmichaelSieve: would overflow"
  | bound < 2   = error "carmichaelSieve: bound must be at least 2"
  | bound < 7   = CS bnd (array (0,0) [(0,0)])
  | otherwise   = CS bnd (carSieve bnd)
    where
      bnd = fromInteger bound


primeList :: PrimeSieve -> [Integer]
primeList (PS 0 bs) = 2:3:5:[fromIntegral (toPrim i) | let (lo,hi) = bounds bs
                                                     , i <- [lo .. hi]
                                                     , unsafeAt bs i
                                                     ]
primeList (PS vO bs) = [vO + fromIntegral (toPrim i)
                            | let (lo,hi) = bounds bs
                            , i <- [lo .. hi]
                            , unsafeAt bs i
                            ]

primes :: [Integer]
primes = 2:3:5:concat [[vO + fromIntegral (toPrim i) | i <- [0 .. li], unsafeAt bs i]
                                | PS vO bs <- psieveList, let (_,li) = bounds bs]

psieveList :: [PrimeSieve]
psieveList = makeSieves plim sqlim 0 0 cache
  where
    plim = 4801     -- prime #647
    sqlim = plim*plim
    cache = runSTUArray $ do
        sieve <- sieveTo 4801
        new <- unsafeNewArray_ (0,1287) :: ST s (STUArray s Int CacheWord)
        let fill j indx
              | 1279 < indx = return new
              | otherwise = do
                p <- unsafeRead sieve indx
                if p
                  then do
                    let !i = indx .&. 7
                        k :: Integer
                        k = fromIntegral (indx `shiftR` 3)
                        strt1 = (k*(30*k + fromIntegral (2*rho i))
                                    + fromIntegral (byte i)) `shiftL` 3
                                    + fromIntegral (idx i)
                        !strt = fromIntegral strt1 .&. 0xFFFFF
                        !skip = fromIntegral (strt1 `shiftR` 20)
                        !ixes = fromIntegral indx `shiftL` 23 + strt `shiftL` 3 + fromIntegral i
                    unsafeWrite new j skip
                    unsafeWrite new (j+1) ixes
                    fill (j+2) (indx+1)
                  else fill j (indx+1)
        fill 0 0

makeSieves :: Integer -> Integer -> Integer -> Integer -> UArray Int Word -> [PrimeSieve]
makeSieves plim sqlim bitOff valOff cache
  | valOff' < sqlim =
      let (nc, bs) = runST $ do
            cch <- {-# SCC "Thaw" #-} unsafeThaw cache :: ST s (STUArray s Int CacheWord)
            bs0 <- slice cch
            fcch <- {-# SCC "FreezeCache" #-} unsafeFreeze cch
            fbs0 <- {-# SCC "FreezeSieve" #-} unsafeFreeze bs0
            return (fcch, fbs0)
      in PS valOff bs : makeSieves plim sqlim bitOff' valOff' nc
  | otherwise       =
      let plim' = plim + 4800
          sqlim' = plim' * plim'
          (nc,bs) = runST $ do
            cch <- growCache bitOff plim cache
            bs0 <- slice cch
            fcch <- unsafeFreeze cch
            fbs0 <- unsafeFreeze bs0
            return (fcch, fbs0)
      in PS valOff bs : makeSieves plim' sqlim' bitOff' valOff' nc
    where
      valOff' = valOff + fromIntegral sieveRange
      bitOff' = bitOff + fromIntegral sieveBits

slice :: STUArray s Int Word -> ST s (STUArray s Int Bool)
slice cache = do
    hi <- snd `fmap` getBounds cache
    sieve <- newArray (0,lastIndex) True
    let treat pr
          | hi < pr     = return sieve
          | otherwise   = do
            w <- unsafeRead cache pr
            if w /= 0
              then unsafeWrite cache pr (w-1)
              else do
                ixes <- unsafeRead cache (pr+1)
                let !stj = ixes .&. 0x7FFFFF
                    !ixw = ixes `shiftR` 23
                    !i = fromIntegral (ixw .&. 7)
                    !k = fromIntegral ixw - i
                    !o = i `shiftL` 3
                    !j = fromIntegral (stj .&. 7)
                    !s = fromIntegral (stj `shiftR` 3)
                (n, u) <- tick k o j s
                let !skip = fromIntegral n `shiftR` 20
                    !strt = fromIntegral n .&. 0xFFFFF
                unsafeWrite cache pr skip
                unsafeWrite cache (pr+1) (ixes - stj + strt `shiftL` 3 + fromIntegral u)
            treat (pr+2)
        tick stp off j ix
          | lastIndex < ix  = return (ix - sieveBits, j)
          | otherwise       = do
            p <- unsafeRead sieve ix
            when p (unsafeWrite sieve ix False)
            tick stp off ((j+1) .&. 7) (ix + stp*delta j + tau (off+j))
    treat 0

-- | Sieve up to bound in one go.
sieveTo :: Integer -> ST s (STUArray s Int Bool)
sieveTo bound = arr
  where
    (bytes,lidx) = idxPr bound
    !mxidx = 8*bytes+lidx
    mxval = 30*fromIntegral bytes + fromIntegral (rho lidx)
    !mxsve = integerSquareRoot mxval
    (kr,r) = idxPr mxsve
    !svbd = 8*kr+r
    arr = do
        ar <- newArray (0,mxidx) True
        let start k i = 8*(k*(30*k+2*rho i) + byte i) + idx i
            tick stp off j ix
              | mxidx < ix = return ()
              | otherwise  = do
                p <- unsafeRead ar ix
                when p (unsafeWrite ar ix False)
                tick stp off ((j+1) .&. 7) (ix + stp*delta j + tau (off+j))
            sift ix
              | svbd < ix = return ar
              | otherwise = do
                p <- unsafeRead ar ix
                when p  (do let i = ix .&. 7
                                k = ix `shiftR` 3
                                !off = i `shiftL` 3
                                !stp = ix - i
                            tick stp off i (start k i))
                sift (ix+1)
        sift 0

spfSieve :: forall s. Int -> ST s (STUArray s Int Int)
spfSieve bound = do
  let (octs,lidx) = idxPr bound
      !mxidx = 8*octs+lidx
      mxval = 30*octs + rho lidx
      !mxsve = integerSquareRoot mxval
      (kr,r) = idxPr mxsve
      !svbd = 8*kr+r
  ar <- unsafeNewArray_ (0,mxidx) :: ST s (STUArray s Int Int)
  let fill i
        | mxidx < i = return ()
        | otherwise = do
          unsafeWrite ar i i
          fill (i+1)
      start k i = 8*(k*(30*k+2*rho i) + byte i) + idx i
      tick p stp off j ix
        | mxidx < ix    = return ()
        | otherwise = do
          s <- unsafeRead ar ix
          when (s == ix) (unsafeWrite ar ix p)
          tick p stp off ((j+1) .&. 7) (ix + stp*delta j + tau (off+j))
      sift ix
        | svbd < ix = return ar
        | otherwise = do
          p <- unsafeRead ar ix
          when (p == ix)  (do let i = ix .&. 7
                                  k = ix `shiftR` 3
                                  !off = i `shiftL` 3
                                  !stp = ix - i
                              tick ix stp off i (start k i))
          sift (ix+1)
  fill 0
  sift 0

totSieve :: Int -> UArray Int Int
totSieve bound = runSTUArray $ do
    ar <- spfSieve bound
    (_,lst) <- getBounds ar
    let tot ix
          | lst < ix    = return ar
          | otherwise   = do
            spf <- unsafeRead ar ix
            if spf == ix
                then unsafeWrite ar ix (toPrim ix - 1)
                else do let !p = toPrim spf
                            !n = toPrim ix
                            (tp,m) = unFact p (n `quot` p)
                        case m of
                          1 -> unsafeWrite ar ix tp
                          _ -> do
                            tm <- unsafeRead ar (toIdx m)
                            unsafeWrite ar ix (tp*tm)
            tot (ix+1)
    tot 0

carSieve :: Int -> UArray Int Int
carSieve bound = runSTUArray $ do
    ar <- spfSieve bound
    (_,lst) <- getBounds ar
    let car ix
          | lst < ix    = return ar
          | otherwise   = do
            spf <- unsafeRead ar ix
            if spf == ix
                then unsafeWrite ar ix (toPrim ix - 1)
                else do let !p = toPrim spf
                            !n = toPrim ix
                            (tp,m) = unFact p (n `quot` p)
                        case m of
                          1 -> unsafeWrite ar ix tp
                          _ -> do
                            tm <- unsafeRead ar (toIdx m)
                            unsafeWrite ar ix (lcm tp tm)
            car (ix+1)
    car 0

growCache :: Integer -> Integer -> UArray Int CacheWord -> ST s (STUArray s Int CacheWord)
growCache offset plim old = do
    let (_,num) = bounds old
        (bt,ix) = idxPr plim
        !start  = 8*bt+ix+1
        !nlim   = plim+4800
    sieve <- sieveTo nlim
    (_,hi) <- getBounds sieve
    more <- countFromTo start hi sieve
    new <- unsafeNewArray_ (0,num+2*more) :: ST s (STUArray s Int CacheWord)
    let copy i
          | num < i   = return ()
          | otherwise = do
            unsafeWrite new i (old `unsafeAt` i)
            copy (i+1)
    copy 0
    let fill j indx
          | hi < indx = return new
          | otherwise = do
            p <- unsafeRead sieve indx
            if p
              then do
                let !i = indx .&. 7
                    k :: Integer
                    k = fromIntegral (indx `shiftR` 3)
                    strt0 = ((k*(30*k + fromIntegral (2*rho i))
                                + fromIntegral (byte i)) `shiftL` 3)
                                    + fromIntegral (idx i)
                    strt1 = strt0 - offset
                    !strt = fromIntegral strt1 .&. 0xFFFFF
                    !skip = fromIntegral (strt1 `shiftR` 20)
                    !ixes = fromIntegral indx `shiftL` 23 + strt `shiftL` 3 + fromIntegral i
                unsafeWrite new j skip
                unsafeWrite new (j+1) ixes
                fill (j+2) (indx+1)
              else fill j (indx+1)
    fill (num+1) start

-- Danger: relies on start and end being the first resp. last
-- index in a Word
-- Do not use except in growCache and psieveFrom
{-# INLINE countFromTo #-}
countFromTo :: Int -> Int -> STUArray s Int Bool -> ST s Int
countFromTo start end ba = do
    wa <- (castSTUArray :: STUArray s Int Bool -> ST s (STUArray s Int Word)) ba
    let !sb = start `shiftR` WSHFT
        !eb = end `shiftR` WSHFT
        count !acc i
          | eb < i    = return acc
          | otherwise = do
            w <- unsafeRead wa i
            count (acc + bitCountWord w) (i+1)
    count 0 sb

-- sieve from n

sieveFrom :: Integer -> [Integer]
sieveFrom n
    | n < 100000    = dropWhile (< n) primes
    | otherwise     = case psieveFrom n of
                        ps -> dropWhile (< n) (ps >>= primeList)

psieveFrom :: Integer -> [PrimeSieve]
psieveFrom n
  | n < 8     = psieveList
  | otherwise = makeSieves plim sqlim bitOff valOff cache
    where
      k0 = (n-7) `quot` 30
      valOff = 30*k0
      bitOff = 8*k0
      start = valOff+7
      ssr = integerSquareRoot (start-1) + 1
      end1 = start - 6 + fromIntegral sieveRange
      plim0 = integerSquareRoot end1
      plim = plim0 + 4801 - (plim0 `rem` 4800)
      sqlim = plim*plim
      cache = runSTUArray $ do
          sieve <- sieveTo plim
          (lo,hi) <- getBounds sieve
          pct <- countFromTo lo hi sieve
          new <- unsafeNewArray_ (0,2*pct-1) ::  ST s (STUArray s Int CacheWord)
          let fill j indx
                | hi < indx = return new
                | otherwise = do
                  p <- unsafeRead sieve indx
                  if p
                    then do
                      let !i = indx .&. 7
                          !moff = i `shiftL` 3
                          k :: Integer
                          k = fromIntegral (indx `shiftR` 3)
                          p = 30*k+fromIntegral (rho i)
                          q0 = (start-1) `quot` p
                          (b0,r0) = idxPr q0
                          (b1,r1) | r0 == 7 = (b0+1,0)
                                  | otherwise = (b0,r0+1)
                          strt0 = ((k*(30*fromIntegral b1 + fromIntegral (rho r1))
                                        + fromIntegral b1 * fromIntegral (rho i)
                                        + fromIntegral (mu (moff + r1))) `shiftL` 3)
                                            + fromIntegral (nu (moff + r1))
                          strt1 = ((k*(30*k + fromIntegral (2*rho i))
                                      + fromIntegral (byte i)) `shiftL` 3)
                                          + fromIntegral (idx i)
                          (strt2,r2)
                              | p < ssr   = (strt0 - bitOff,r1)
                              | otherwise = (strt1 - bitOff, i)
                          !strt = fromIntegral strt2 .&. 0xFFFFF
                          !skip = fromIntegral (strt2 `shiftR` 20)
                          !ixes = fromIntegral indx `shiftL` 23 + strt `shiftL` 3 + fromIntegral r2
                      unsafeWrite new j skip
                      unsafeWrite new (j+1) ixes
                      fill (j+2) (indx+1)
                    else fill j (indx+1)
          fill 0 0

-- prime counting

nthPrime :: Integer -> Integer
nthPrime 1      = 2
nthPrime 2      = 3
nthPrime 3      = 5
nthPrime 4      = 7
nthPrime 5      = 11
nthPrime 6      = 13
nthPrime n
  | n < 1       = error "nthPrime: negative argument"
  | n < 200000  = let bd0 = nthPrimeApprox n
                      bnd = bd0 + bd0 `quot` 32 + 37
                      !sv = primeSieve bnd
                  in countToNth (n-3) [sv]
  | otherwise   = countToNth (n-3) (psieveList)

-- find the n-th set bit in a list of PrimeSieves,
-- aka find the (n+3)-rd prime
countToNth :: Integer -> [PrimeSieve] -> Integer
countToNth !n ps = runST (countDown n ps)

countDown :: Integer -> [PrimeSieve] -> ST s Integer
countDown !n (ps@(PS v0 bs) : more)
  | n > 278734 || (v0 /= 0 && n > 253000) = do
    ct <- countAll ps
    countDown (n - fromIntegral ct) more
  | otherwise = do
    stu <- unsafeThaw bs
    wa <- (castSTUArray :: STUArray s Int Bool -> ST s (STUArray s Int Word)) stu
    let go !k i
          | i == sieveWords  = countDown k more
          | otherwise   = do
            w <- unsafeRead wa i
            let !bc = fromIntegral $ bitCountWord w
            if bc < k
                then go (k-bc) (i+1)
                else let !j = fromIntegral (bc - k)
                         !px = top w j (fromIntegral bc)
                     in return (v0 + toPrim (px+(i `shiftL` WSHFT)))
    go n 0
countDown _ [] = error "Prime stream ended prematurely"

-- count all set bits in a chunk, do it wordwise for speed.
countAll :: PrimeSieve -> ST s Int
countAll (PS _ bs) = do
    stu <- unsafeThaw bs
    wa <- (castSTUArray :: STUArray s Int Bool -> ST s (STUArray s Int Word)) stu
    let go !ct i
            | i == sieveWords = return ct
            | otherwise = do
                w <- unsafeRead wa i
                go (ct + bitCountWord w) (i+1)
    go 0 0

-- Find the j-th highest of bc set bits in the Word w.
top :: Word -> Int -> Int -> Int
top w j bc = go 0 TOPB TOPM bn w
    where
      !bn = bc-j
      go !bs a !msk !ix 0 = error "Too few bits set"
      go bs 0 _ _ wd = if wd .&. 1 == 0 then error "Too few bits, shift 0" else bs
      go bs a msk ix wd =
        case bitCountWord (wd .&. msk) of
          lc | lc < ix  -> go (bs+a) a msk (ix-lc) (wd `uncheckedShiftR` a)
             | otherwise ->
               let !na = a `shiftR` 1
               in go bs na (msk `uncheckedShiftR` na) ix wd

-- Find the p-part of the totient of (p*m) and the cofactor
-- of the p-power in m.
{-# INLINE unFact #-}
unFact :: Int -> Int -> (Int,Int)
unFact p m = go (p-1) m
  where
    go !tt k = case k `quotRem` p of
                 (q,0) -> go (p*tt) q
                 _ -> (tt,k)

-- Auxiliary stuff, conversion between number and index,
-- remainders modulo 30 and related things.

{-# SPECIALISE idxPr :: Integer -> (Int,Int),
                        Int -> (Int,Int)
  #-}
{-# INLINE idxPr #-}
idxPr :: Integral a => a -> (Int,Int)
idxPr n0 = (fromIntegral bytes0, rm3)
  where
    n = if (fromIntegral n0 .&. 1 == (1 :: Int))
            then n0 else (n0-1)
    (bytes0,rm0) = (n-7) `quotRem` 30
    rm1 = fromIntegral rm0
    rm2 = rm1 `quot` 3
    rm3 = min 7 (if rm2 > 5 then rm2-1 else rm2)

{-# SPECIALISE toPrim :: Int -> Integer,
                         Int -> Int
    #-}
{-# INLINE toPrim #-}
toPrim :: Integral a => Int -> a
toPrim ix = 30*fromIntegral k + fromIntegral (rho i)
  where
    i = ix .&. 7
    k = ix `shiftR` 3

-- Assumes n >= 7, gcd n 30 == 1
{-# INLINE toIdx #-}
toIdx :: Int -> Int
toIdx n = 8*q+r2
  where
    (q,r) = (n-7) `quotRem` 30
    r1 = r `quot` 3
    r2 = min 7 (if r1 > 5 then r1-1 else r1)

{-# INLINE rho #-}
rho :: Int -> Int
rho i = unsafeAt residues i

residues :: UArray Int Int
residues = listArray (0,7) [7,11,13,17,19,23,29,31]

{-# INLINE delta #-}
delta :: Int -> Int
delta i = unsafeAt deltas i

deltas :: UArray Int Int
deltas = listArray (0,7) [4,2,4,2,4,6,2,6]

{-# INLINE tau #-}
tau :: Int -> Int
tau i = unsafeAt taus i

taus :: UArray Int Int
taus = listArray (0,63)
        [  7,  4,  7,  4,  7, 12,  3, 12
        , 12,  6, 11,  6, 12, 18,  5, 18
        , 14,  7, 13,  7, 14, 21,  7, 21
        , 18,  9, 19,  9, 18, 27,  9, 27
        , 20, 10, 21, 10, 20, 30, 11, 30
        , 25, 12, 25, 12, 25, 36, 13, 36
        , 31, 15, 31, 15, 31, 47, 15, 47
        , 33, 17, 33, 17, 33, 49, 17, 49
        ]

{-# INLINE byte #-}
byte :: Int -> Int
byte i = unsafeAt startByte i

startByte :: UArray Int Int
startByte = listArray (0,7) [1,3,5,9,11,17,27,31]

{-# INLINE idx #-}
idx :: Int -> Int
idx i = unsafeAt startIdx i

startIdx :: UArray Int Int
startIdx = listArray (0,7) [4,7,4,4,7,4,7,7]

{-# INLINE mu #-}
mu :: Int -> Int
mu i = unsafeAt mArr i

{-# INLINE nu #-}
nu :: Int -> Int
nu i = unsafeAt nArr i

mArr :: UArray Int Int
mArr = listArray (0,63)
        [ 1,  2,  2,  3,  4,  5,  6,  7
        , 2,  3,  4,  6,  6,  8, 10, 11
        , 2,  4,  5,  7,  8,  9, 12, 13
        , 3,  6,  7,  9, 10, 12, 16, 17
        , 4,  6,  8, 10, 11, 14, 18, 19
        , 5,  8,  9, 12, 14, 17, 22, 23
        , 6, 10, 12, 16, 18, 22, 27, 29
        , 7, 11, 13, 17, 19, 23, 29, 31
        ]

nArr :: UArray Int Int
nArr = listArray (0,63)
        [ 4, 3, 7, 6, 2, 1, 5, 0
        , 3, 7, 5, 0, 6, 2, 4, 1
        , 7, 5, 4, 1, 0, 6, 3, 2
        , 6, 0, 1, 4, 5, 7, 2, 3
        , 2, 6, 0, 5, 7, 3, 1, 4
        , 1, 2, 6, 7, 3, 4, 0, 5
        , 5, 4, 3, 2, 1, 0, 7, 6
        , 0, 1, 2, 3, 4, 5, 6, 7
        ]