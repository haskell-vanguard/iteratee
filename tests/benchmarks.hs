{-# LANGUAGE RankNTypes, KindSignatures, NoMonomorphismRestriction #-}

-- some basic benchmarking of iteratee

module Main where

import Data.Iteratee
import qualified Data.Iteratee.ListLike as I
import Data.Iteratee.ListLike (enumPureNChunk, stream2list, stream2stream)
import Data.Word
import Data.Monoid
import qualified Data.ByteString as BS
import Control.Applicative
import Control.DeepSeq
import Control.Monad.Identity
import Control.Monad
import qualified Data.ListLike as LL

import Criterion.Main

main = defaultMain [allListBenches, allByteStringBenches]

-- -------------------------------------------------------------
-- helper functions and data

-- |Hold information about a benchmark.  This allows each
-- benchmark (and baseline) to be created independently of the stream types,
-- for easy comparison of different streams.
-- BDList is for creating baseline comparison functions.  Although the name
-- is BDList, it will work for any stream type (e.g. bytestrings).
data BD a b s (m :: * -> *) = BDIter1 String (a -> b) (Iteratee s m a) 
  | BDIterN String Int (a -> b) (Iteratee s m a)
  | BDList String (s -> b) s

id1  name i = BDIter1 name id i
idN  name i = BDIterN name 5 id i
idNl name i = BDIterN name 1000 id i

defTotalSize = 10000

makeList name f = BDList name f [1..defTotalSize]

makeBench :: BD n eval [Int] Identity -> Benchmark
makeBench (BDIter1 n eval i) = bench n $
  proc eval runIdentity (enumPure1Chunk [1..defTotalSize]) i
makeBench (BDIterN n csize eval i) = bench n $
  proc eval runIdentity (enumPureNChunk [1..defTotalSize] csize) i
makeBench (BDList n f l) = bench n $ whnf f l

packedBS :: BS.ByteString
packedBS  = (BS.pack [1..defTotalSize])

makeBenchBS (BDIter1 n eval i) = bench n $
  proc eval runIdentity (enumPure1Chunk packedBS) i
makeBenchBS (BDIterN n csize eval i) = bench n $
  proc eval runIdentity (enumPureNChunk packedBS csize) i
makeBenchBS (BDList n f l) = error "makeBenchBS can't be called on BDList"

proc :: (Functor m, Monad m)
  => (a -> b) --function to force evaluation of result
  -> (m a -> a)
  -> I.Enumerator s m a
  -> I.Iteratee s m a
  -> Pure
proc eval runner enum iter = whnf (eval . runner . (I.run <=< enum)) iter

-- -------------------------------------------------------------
-- benchmark groups
makeGroup n = bgroup n . map makeBench

makeGroupBS :: String -> [BD t t1 BS.ByteString Identity] -> Benchmark
makeGroupBS n = bgroup n . map makeBenchBS

listbench = makeGroup "stream2List" (slistBenches :: [BD [Int] () [Int] Identity])
streambench = makeGroup "stream" (streamBenches :: [BD [Int] () [Int] Identity])
breakbench = makeGroup "break" $ break0 : break0' : breakBenches
headsbench = makeGroup "heads" headsBenches
dropbench = makeGroup "drop" $ drop0 : dropBenches
lengthbench = makeGroup "length" listBenches
takebench = makeGroup "take" $ take0 : takeBenches
takeUpTobench = makeGroup "takeUpTo" takeUpToBenches
mapbench = makeGroup "map" $ mapBenches
foldbench = makeGroup "fold" $ foldBenches
convbench = makeGroup "convStream" convBenches
miscbench = makeGroup "other" miscBenches

listbenchbs = makeGroupBS "stream2List" slistBenches
streambenchbs = makeGroupBS "stream" streamBenches
breakbenchbs = makeGroupBS "break" breakBenches
headsbenchbs = makeGroupBS "heads" headsBenches
dropbenchbs = makeGroupBS "drop" dropBenches
lengthbenchbs = makeGroupBS "length" listBenches
takebenchbs = makeGroupBS "take" takeBenches
takeUpTobenchbs = makeGroupBS "takeUpTo" takeUpToBenches
mapbenchbs = makeGroupBS "map" mapBenches
foldbenchbs = makeGroupBS "fold" $ foldBenches
convbenchbs = makeGroupBS "convStream" convBenches
miscbenchbs = makeGroupBS "other" miscBenches


allListBenches = bgroup "list" [listbench, streambench, breakbench, headsbench, dropbench, lengthbench, takebench, takeUpTobench, mapbench, foldbench, convbench, miscbench]

allByteStringBenches = bgroup "bytestring" [listbenchbs, streambenchbs, breakbenchbs, headsbenchbs, dropbenchbs, lengthbenchbs, takebenchbs, takeUpTobenchbs, mapbenchbs, foldbenchbs, convbenchbs, miscbenchbs]

list0 = makeList "list one go" deepseq
list1 = BDIter1 "stream2list one go" (flip deepseq ()) stream2list
list2 = BDIterN "stream2list chunk by 4" 4 (flip deepseq ()) stream2list
list3 = BDIterN "stream2list chunk by 1024" 1024 (flip deepseq ()) stream2list
slistBenches = [list1, list2, list3]

stream1 = BDIter1 "stream2stream one go" (flip deepseq ()) stream2stream
stream2 = BDIterN "stream2stream chunk by 4" 4 (flip deepseq ()) stream2stream
stream3 = BDIterN "stream2stream chunk by 1024" 1024 (flip deepseq ()) stream2stream
streamBenches = [stream1, stream2, stream3]

break0 = makeList "break early list" (fst . Prelude.break (>5))
break0' = makeList "break never list" (fst . Prelude.break (<0))
break1 = id1 "break early one go" (I.break (>5))
break2 = id1 "break never" (I.break (<0)) -- not ever true.
break3 = idN "break early chunked" (I.break (>500))
break4 = idN "break never chunked" (I.break (<0)) -- not ever true
break5 = idN "break late chunked" (I.break (>8000))
breakBenches = [break1, break2, break3, break4, break5]

heads1 = id1 "heads null" (I.heads $ LL.fromList [])
heads2 = id1 "heads 1" (I.heads $ LL.fromList [1])
heads3 = id1 "heads 100" (I.heads $ LL.fromList [1..100])
heads4 = idN "heads 100 over chunks" (I.heads $ LL.fromList [1..100])
headsBenches = [heads1, heads2, heads3, heads4]

benchpeek = id1 "peek" I.peek
benchskip = id1 "skipToEof" (I.skipToEof >> return Nothing)
miscBenches = [benchpeek, benchskip]

drop0 = makeList "drop plain (list only)"
  ( flip seq () . Prelude.drop 100)
drop1 = id1 "drop null" (I.drop 0)
drop2 = id1 "drop plain" (I.drop 100)
drop3 = idN "drop over chunks" (I.drop 100)

dropw0 = makeList "dropWhile all (list only)" (Prelude.dropWhile (const True))
dropw1 = id1 "dropWhile all" (I.dropWhile (const True))
dropw2 = idN "dropWhile all chunked" (I.dropWhile (const True))
dropw3 = id1 "dropWhile small" (I.dropWhile ( < 100))
dropw4 = id1 "dropWhile large" (I.dropWhile ( < 6000))
dropBenches = [drop1, drop2, drop3, dropw1, dropw2, dropw3, dropw4]


l1 = makeList "length of list" Prelude.length
l2 = id1 "length single iteratee" I.length
l3 = idN "length chunked" I.length
listBenches = [l2, l3]

take0 = makeList "take length of list long" (Prelude.length . Prelude.take 1000)
take1 = id1 "take head short one go" (I.joinI $ I.take 20 I.head)
take2 = id1 "take head long one go" (I.joinI $ I.take 1000 I.head)
take3 = idN "take head short chunked" (I.joinI $ I.take 20 I.head)
take4 = idN "take head long chunked" (I.joinI $ I.take 1000 I.head)
take5 = id1 "take length long one go" (I.joinI $ I.take 1000 I.length)
take6 = idN "take length long chunked" (I.joinI $ I.take 1000 I.length)
takeBenches = [take1, take2, take3, take4, take5, take6]

takeUpTo1 = id1 "takeUpTo head short one go" (I.joinI $ I.take 20 I.head)
takeUpTo2 = id1 "takeUpTo head long one go" (I.joinI $ I.takeUpTo 1000 I.head)
takeUpTo3 = idN "takeUpTo head short chunked" (I.joinI $ I.takeUpTo 20 I.head)
takeUpTo4 = idN "takeUpTo head long chunked" (I.joinI $ I.takeUpTo 1000 I.head)
takeUpTo5 = id1 "takeUpTo length long one go" (I.joinI $ I.takeUpTo 1000 I.length)
takeUpTo6 = idN "takeUpTo length long chunked" (I.joinI $ I.takeUpTo 1000 I.length)
takeUpToBenches = [takeUpTo1, takeUpTo2, takeUpTo3, takeUpTo4, takeUpTo5, takeUpTo6]

map1 = id1 "map length one go" (I.joinI $ I.rigidMapStream id I.length)
map2 = idN "map length chunked" (I.joinI $ I.rigidMapStream id I.length)
map3 = id1 "map head one go" (I.joinI $ I.rigidMapStream id I.head)
map4 = idN "map head chunked" (I.joinI $ I.rigidMapStream id I.head)
mapBenches = [map1, map2, map3, map4]

foldB1 = idNl "foldl' sum" (I.foldl' (+) 0)
foldB2 = idNl "mapReduce foldl' 2 sum" (getSum <$> I.mapReduce 2 (Sum . LL.foldl' (+) 0))
foldB3 = idNl "mapReduce foldl' 4 sum" (getSum <$> I.mapReduce 4 (Sum . LL.foldl' (+) 0))
foldBenches = [foldB1, foldB2, foldB3]

conv1 = idN "convStream id head chunked" (I.joinI . I.convStream idChunk $ I.head)
conv2 = idN "convStream id length chunked" (I.joinI . I.convStream idChunk $ I.length)
idChunk = I.liftI step
  where
    step (I.Chunk xs)
      | LL.null xs      = idChunk
      | True            = idone xs (I.Chunk mempty)
convBenches = [conv1, conv2]

instance NFData BS.ByteString where

instance NFData a => NFData (Sum a) where
  rnf (Sum a) = rnf a
