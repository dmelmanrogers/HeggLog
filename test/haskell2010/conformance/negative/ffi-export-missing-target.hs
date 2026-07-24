module Main where

foreign export ccall "haskell_compiler_missing_export" missing :: Int -> Int

main :: Int
main = 0
