{- | Provide iteratee-based IO as described in Oleg Kiselyov's paper http://okmij.org/ftp/Haskell/Iteratee/.

Oleg's original code uses lists to store buffers of data for reading in the iteratee.  This package allows the use of arbitrary types through use of the StreamChunk type class.  See Data.Iteratee.WrappedByteString for implementation details.

-}

module Data.Iteratee (
  module Data.Iteratee.Binary,
  module Data.Iteratee.Iteratee,
  fileDriver,
  fileDriverVBuf,
  fileDriverRandom,
  fileDriverRandomVBuf
)

where

import Data.Iteratee.Binary
import Data.Iteratee.IO
import Data.Iteratee.Iteratee
