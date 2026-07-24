module Main where

listAppend :: [Int]
listAppend = [1, 2] ++ [] ++ [3, 4]

stringAppend :: String
stringAppend = "haskell-" ++ "compiler"

leftSection :: String -> String
leftSection = ("he" ++)

rightSection :: String -> String
rightSection = (++ "suffix")

main :: IO ()
main = do
  print listAppend
  putStrLn stringAppend
  print ([1] ++ [2] ++ [3])
  print ((++) [True] [False])
  putStrLn (leftSection "y")
  putStrLn (rightSection "pre")
  return ()
