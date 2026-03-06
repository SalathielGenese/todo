{-# LANGUAGE LambdaCase #-}

-- \| A minimal CLI todo manager backed by a plain-text file (~/.todo).
--
-- Each line in the file is a Haskell 'Show'/'Read' serialized 'Task'.
-- Tasks have an auto-incremented integer ID, a description, an optional
-- due date, and an optional completion timestamp.
--
-- Run with @--help@ or no arguments for usage.

{- HLINT ignore "Functor law" -}

import Control.Applicative ((<|>))
import Control.Exception (IOException, catch)
import Data.Char (isSpace, toLower)
import Data.Functor ((<$>), (<&>))
import Data.List (find, sortBy)
import Data.Maybe (isNothing)
import Data.Ord (Down (..), comparing)
import Data.Time (CalendarDiffTime (..), UTCTime (..), addGregorianMonthsClip, addUTCTime, diffUTCTime, getCurrentTime)
import Data.Time.Format.ISO8601 (iso8601ParseM, iso8601Show)
import System.Directory (getHomeDirectory)
import System.Environment (getArgs)
import System.IO (hPutStrLn, readFile', stderr)
import Text.Read (readMaybe)

-- * Data types

{- | A task: @Task id description created due done@.
Serialized to disk via 'Show'/'Read', one per line.
-}
data Task = Task Int String UTCTime (Maybe UTCTime) (Maybe UTCTime)
    deriving (Show, Read)

-- | Parsed CLI command.
data Command
    = CommandHelp [String]
    | CommandSearch String
    | CommandAdd String (Maybe UTCTime)
    | CommandEdit Int String (Maybe UTCTime) (Maybe UTCTime)

-- * Task accessors

taskId :: Task -> Int
taskId (Task i _ _ _ _) = i

taskDesc :: Task -> String
taskDesc (Task _ d _ _ _) = d

taskCreated :: Task -> UTCTime
taskCreated (Task _ _ c _ _) = c

taskDue :: Task -> Maybe UTCTime
taskDue (Task _ _ _ d _) = d

taskDone :: Task -> Maybe UTCTime
taskDone (Task _ _ _ _ d) = d

-- * Main

main :: IO ()
main = parseCommand >>= execute

-- * Storage

-- | Absolute path to the storage file: @~/.todo@.
storagePath :: IO FilePath
storagePath = getHomeDirectory <&> (++ "/.todo")

-- | Read and deserialize all tasks from disk. Returns @[]@ if the file is missing.
loadTasks :: IO [Task]
loadTasks = catch @IOException (storagePath >>= readFile') (\_ -> pure "") <&> map read . filter (not . null) . lines

-- | Next available ID: one past the current maximum (or 1 if no tasks exist).
nextId :: IO Int
nextId = loadTasks <&> (+ 1) . foldr (max . taskId) 0

-- * Command parsing

{- | Parse CLI arguments into a 'Command'.
Due dates accept both absolute ISO 8601 timestamps (e.g. @2026-03-06T12:00:00Z@)
and ISO 8601 durations relative to now (e.g. @P3DT12H@).
-}
parseCommand :: IO Command
parseCommand =
    getArgs >>= \case
        -- Help
        ("--help" : args) -> pure $ CommandHelp args
        ("-h" : args) -> pure $ CommandHelp args
        -- Search
        ["?", terms] -> pure $ CommandSearch terms
        ["?"] -> pure $ CommandSearch ""
        [] -> pure $ CommandSearch ""
        -- Edit
        [id, task, due]
            | Just ioDue <- parseDue due
            , Just id :: Maybe Int <- readMaybe id
            , isNotBlank task ->
                ioDue <&> \d -> CommandEdit id task (Just d) Nothing
        [id, due]
            | Just ioDue <- parseDue due
            , Just id :: Maybe Int <- readMaybe id ->
                ioDue <&> \d -> CommandEdit id "" (Just d) Nothing
        [id, task]
            | Just id :: Maybe Int <- readMaybe id
            , isNotBlank task ->
                pure $ CommandEdit id task Nothing Nothing
        [id]
            | Just id :: Maybe Int <- readMaybe id ->
                getCurrentTime <&> CommandEdit id "" Nothing . Just
        -- Add
        [task, due]
            | Just ioDue <- parseDue due
            , isNotBlank task ->
                ioDue <&> \d -> CommandAdd task $ Just d
        [task]
            | isNotBlank task ->
                pure $ CommandAdd task Nothing
        -- (catch-all)
        args -> pure $ CommandHelp args

-- | Try to parse an ISO 8601 absolute timestamp or duration into a 'UTCTime' action.
parseDue :: String -> Maybe (IO UTCTime)
parseDue s =
    (pure <$> (iso8601ParseM s :: Maybe UTCTime))
        <|> (resolveOffset <$> (iso8601ParseM s :: Maybe CalendarDiffTime))
  where
    resolveOffset (CalendarDiffTime months dt) =
        getCurrentTime <&> \now ->
            addUTCTime dt (now{utctDay = addGregorianMonthsClip months (utctDay now)})

-- * Command execution

execute :: Command -> IO ()
execute (CommandHelp []) =
    (hPutStrLn stderr . unlines)
        [ "USAGE: todo [...<arguments>]"
        , ""
        , "  todo --help"
        , "  todo -h"
        , "       Print this help message"
        , ""
        , "  todo <id> <task> <due>"
        , "  todo <id> <due>"
        , "  todo <id> <task>"
        , "       Update a task with new <task> description and/or <due> date"
        , ""
        , "  todo <id>"
        , "       Mark a task as done, just now"
        , ""
        , "  todo <task> <due>"
        , "  todo <task>"
        , "       Register a new <task>, eventually with a <due> date"
        , ""
        , "  todo ? <terms>"
        , "  todo ?"
        , "  todo"
        , "       List pending tasks, eventually filtered by <terms>, sorted by due date"
        , ""
        , "API NOTES:"
        , "- <id> must be a 1+ integer"
        , "- Once done, a task cannot be undone"
        , "- <task> as blank strings are invalid"
        , "- <due> date cannot be unset after it has been set"
        , "- <due> must be ISO 8601 date or duration, e.g. '2026-03-06T12:00:00Z' or 'P3DT12H'"
        , "- <id> is printed to the standard output when an update did happen"
        ]
execute (CommandHelp _) = do
    hPutStrLn stderr $ ansi "31" "Invalid usage" ++ "\n"
    execute $ CommandHelp []
-- \| Search: display pending tasks in a table, optionally filtered by fuzzy match.
-- Sorted by due date (earliest first, no-due-date last).
-- Due dates in blue when 1/3 of allotted time has elapsed, red when overdue.
-- Matched characters in task descriptions are highlighted in bold cyan.
execute (CommandSearch terms) = do
    now <- getCurrentTime
    loadTasks >>= putStr . formatTable now lterms . sortBy (comparing dueKey) . filter (isPendingMatch lterms)
  where
    lterms = map toLower terms
-- \| Edit: update an existing task's description, due date, and/or done timestamp.
-- Blank descriptions and 'Nothing' dues are treated as "keep current value".
-- Prints the task ID on success; does nothing if the ID is not found.
execute (CommandEdit id task due done) = do
    ts <- loadTasks
    case find ((== id) . taskId) ts of
        Nothing -> pure ()
        Just _ -> do
            p <- storagePath
            writeFile p $ unlines $ map (show . update) ts
            print id
  where
    update t | taskId t /= id = t
    update (Task _ ttask created ddue ddone) =
        Task id (if isNotBlank task then task else ttask) created (due <|> ddue) (ddone <|> done)
-- \| Add: append a new task to the file and print its assigned ID.
execute (CommandAdd task due) = do
    id <- nextId
    p <- storagePath
    created <- getCurrentTime
    appendFile p $ show (Task id task created due Nothing) ++ "\n"
    print id

-- * Search & filtering

-- | Match pending tasks against lowercased search terms.
isPendingMatch :: String -> Task -> Bool
isPendingMatch lterms t = isNothing (taskDone t) && fuzzy lterms (map toLower (taskDesc t))

-- | Subsequence match: every character in the query appears in order in the target.
fuzzy :: String -> String -> Bool
fuzzy [] _ = True
fuzzy _ [] = False
fuzzy (q : qs) (t : ts)
    | q == t = fuzzy qs ts
    | otherwise = fuzzy (q : qs) ts

-- | Sort key: tasks with due dates first (earliest first), then tasks without.
dueKey :: Task -> (Down Bool, Maybe UTCTime)
dueKey t = (Down (isNothing (taskDue t)), taskDue t)

-- * Table formatting

-- | Format tasks as an aligned table with ANSI-colored due dates and highlighted matches.
formatTable :: UTCTime -> String -> [Task] -> String
formatTable now lterms rows = unlines $ header : separator : map formatRow rows
  where
    wId = foldl max 2 $ map (length . show . taskId) rows
    wDesc = min 40 $ foldl max 4 $ map (length . taskDesc) rows
    wCreated = foldl max 7 $ map (length . iso8601Show . taskCreated) rows
    wDue = foldl max 3 $ map (length . maybe "-" iso8601Show . taskDue) rows
    header = rpad wId "ID" ++ "  " ++ pad wDesc "Task" ++ "  " ++ pad wCreated "Created" ++ "  " ++ "Due"
    separator = replicate wId '-' ++ "  " ++ replicate wDesc '-' ++ "  " ++ replicate wCreated '-' ++ "  " ++ replicate wDue '-'
    formatRow t =
        let desc = trunc wDesc (taskDesc t)
         in rpad wId (show (taskId t))
                ++ "  "
                ++ padAnsi wDesc desc (highlightMatches lterms desc)
                ++ "  "
                ++ pad wCreated (iso8601Show (taskCreated t))
                ++ "  "
                ++ colorizeDue now t
    rpad w s = replicate (w - length s) ' ' ++ s
    pad w s = s ++ replicate (w - length s) ' '
    padAnsi w plain s = s ++ replicate (w - length plain) ' '
    trunc w s
        | length s > w = take (w - 1) s ++ "…"
        | otherwise = s

-- | Colorize a due date: red if overdue, blue if 1/3 of allotted time has elapsed.
colorizeDue :: UTCTime -> Task -> String
colorizeDue now t = case taskDue t of
    Nothing -> "-"
    Just d
        | d < now -> ansi "1;31" (iso8601Show d)
        | diffUTCTime now (taskCreated t) >= diffUTCTime d (taskCreated t) / 3 -> ansi "1;34" (iso8601Show d)
        | otherwise -> iso8601Show d

-- | Highlight fuzzy-matched characters in bold cyan.
highlightMatches :: String -> String -> String
highlightMatches [] rest = rest
highlightMatches _ [] = []
highlightMatches (q : qs) (t : ts)
    | toLower q == toLower t = ansi "1;36" [t] ++ highlightMatches qs ts
    | otherwise = t : highlightMatches (q : qs) ts

-- * Utilities

-- | Wrap text in an ANSI escape sequence.
ansi :: String -> String -> String
ansi code s = "\ESC[" ++ code ++ "m" ++ s ++ "\ESC[0m"

isNotBlank :: String -> Bool
isNotBlank = not . all isSpace
