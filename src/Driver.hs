{-# LANGUAGE OverloadedStrings #-}
module Driver( driverMain ) where

{-                               DOCUMENTATION                              -}
{-
    Driver...
-}

{-                                 MODULES                                  -}
-- Standard
import qualified Data.ByteString.Char8 as BC8
import qualified Data.Attoparsec as Attoparsec
import Control.Monad
import qualified System.Environment
import System.IO (stdout, stderr)
import qualified System.Exit
import qualified System.Directory
import System.FilePath ((</>))

-- Chomp
import SyntaxTree
import Parser
import OperationalSemantics

{-                              IMPLEMENTATION                              -}

driverMain :: IO ()
driverMain = do
  -- Read command line arguments
  args <- System.Environment.getArgs
  [sourceFilePath, outputFilePath] <- if length args < 1
    then BC8.hPutStrLn stderr "No arguments supplied." >> printUsage >> (System.Exit.exitWith $ System.Exit.ExitFailure 1)
    else if head args == "--help"
      then printUsage >> System.Exit.exitSuccess
      else if length args < 2
        then BC8.hPutStrLn stderr "Too few arguments supplied." 
          >> printUsage 
          >> (System.Exit.exitWith $ System.Exit.ExitFailure 1)
        else if length args > 2
          then BC8.hPutStrLn stderr "Too many arguments supplied." 
            >> printUsage 
            >> (System.Exit.exitWith $ System.Exit.ExitFailure 1)
          else return args
  -- Read the source file contents
  -- TODO: try/catch
  sourceFileContents <- loadSourceFile sourceFilePath
  -- Parse the source code
  case Attoparsec.parseOnly parseLangLang sourceFileContents of
    Left message -> BC8.hPutStrLn stderr ("Parse Error: " `BC8.append` (BC8.pack message))
    Right result -> 
      BC8.hPutStrLn stdout "Done."
      >> (writeOutputFile outputFilePath $ BC8.pack $ show result)
  where
    loadSourceFile path = do
      currentDirPath <- System.Directory.getCurrentDirectory
      BC8.readFile (currentDirPath </> path) -- (uses path directly if it is already absolute)
    writeOutputFile path output = do
      currentDirPath <- System.Directory.getCurrentDirectory
      BC8.writeFile (currentDirPath </> path) output -- (uses path directly if it is already absolute)

printUsage :: IO ()
printUsage = putStrLn "USAGE: chomp sourceFile outputFile"
