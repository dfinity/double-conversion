{-# LANGUAGE MagicHash, Rank2Types #-}

-- |
-- Module      : Data.Double.Conversion
-- Copyright   : (c) 2011 MailRank, Inc.
--
-- License     : BSD-style
-- Maintainer  : bos@mailrank.com
-- Stability   : experimental
-- Portability : GHC
--
-- Fast, efficient support for converting between double precision
-- floating point values and text.

module Data.Double.Conversion
    (
      toExponential
    , toFixed
    , toPrecision
    , toShortest
    ) where

import Control.Monad (when)
import Control.Monad.ST (unsafeIOToST, runST)
import Data.Double.Conversion.FFI
import Data.Text.Internal (Text(Text))
import Foreign.C.Types (CDouble, CInt)
import GHC.Prim (MutableByteArray#)
import qualified Data.Text.Array as A

-- | Compute a representation in exponential format with the requested
-- number of digits after the decimal point. The last emitted digit is
-- rounded.  If -1 digits are requested, then the shortest exponential
-- representation is computed.
toExponential :: Int -> Double -> Text
toExponential ndigits = convert "toExponential" len $ \val mba ->
                        c_Text_ToExponential val mba (fromIntegral ndigits)
  where len = c_ToExponentialLength
        {-# NOINLINE len #-}

-- | Compute a decimal representation with a fixed number of digits
-- after the decimal point. The last emitted digit is rounded.
toFixed :: Int -> Double -> Text
toFixed ndigits = convert "toFixed" len $ \val mba ->
                  c_Text_ToFixed val mba (fromIntegral ndigits)
  where len = c_ToFixedLength
        {-# NOINLINE len #-}

-- | Compute the shortest string of digits that correctly represent
-- the input number.
toShortest :: Double -> Text
toShortest = convert "toShortest" len c_Text_ToShortest
  where len = c_ToShortestLength
        {-# NOINLINE len #-}

-- | Compute @precision@ leading digits of the given value either in
-- exponential or decimal format. The last computed digit is rounded.
toPrecision :: Int -> Double -> Text
toPrecision ndigits = convert "toPrecision" len $ \val mba ->
                      c_Text_ToPrecision val mba (fromIntegral ndigits)
  where len = c_ToPrecisionLength
        {-# NOINLINE len #-}

convert :: String -> CInt
        -> (forall s. CDouble -> MutableByteArray# s -> IO CInt)
        -> Double -> Text
convert func len act val = runST go
  where
    go = do
      buf <- A.new (fromIntegral len)
      size <- unsafeIOToST $ act (realToFrac val) (A.maBA buf)
      when (size == -1) .
        fail $ "Data.Double.Conversion." ++ func ++
               ": conversion failed (invalid precision requested)"
      frozen <- A.unsafeFreeze buf
      return $ Text frozen 0 (fromIntegral size)
