-- A simple wc-like program using Data.Iteratee
module Main where

import Prelude as P
import Data.Iteratee
import Data.Iteratee.Char as C
import qualified Data.Iteratee as I
import qualified Data.ByteString.Char8 as BC
import Data.Word
import Data.ListLike as LL
import System


-- An iteratee to calculate the number of characters in a stream.  Very basic.
numChars :: (Monad m, ListLike s el) => I.Iteratee s m Int
numChars = I.length

-- An iteratee to calculate the number of words in a stream of Word8's.
-- this operates on a Word8 stream because that's the only way to use
-- ByteString's, however each word in the stream produced by enumWordsBS
-- is a (strict) bytestring that can be used with Data.ByteString.Char8.
-- this is not terribly efficient, it's the analog of
-- length . BC.words
numWords :: Monad m => I.Iteratee BC.ByteString m Int
numWords = I.joinI $ enumWordsBS I.length

-- Count the number of lines, similar to numWords
numLines :: Monad m => I.Iteratee BC.ByteString m Int
numLines = I.joinI $ enumLinesBS I.length

allIter :: Monad m => I.Iteratee BC.ByteString m ((Int, Int), Int)
allIter = numLines `I.enumPar` numWords `I.enumPar` numChars

main = do
  f:_ <- getArgs
  words <- fileDriverVBuf (2^16) allIter f
  print words
