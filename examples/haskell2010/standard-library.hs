module Main where

import Control.Monad (Functor (..), return)
import Data.List ((++), foldl, head, map, null)
import Data.Maybe (Maybe (..))
import System.IO (IO, print, putStrLn)

emptyInts :: [Int]
emptyInts = []

sumList :: [Int] -> Int
sumList xs = foldl (+) 0 xs

maybeValue :: Maybe Int
maybeValue = Just (head ([4] ++ [5]))

selected :: Int
selected = head ([4] ++ [5])

main :: IO ()
main = do
  print (sumList (map (+ 1) [1, 2, 3]))
  print (sumList (fmap (+ 1) [1, 2, 3]))
  print (selected + 1)
  print (null emptyInts)
  fmap id (putStrLn "stdlib")
  return ()
