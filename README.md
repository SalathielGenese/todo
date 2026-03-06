# todo

A CLI tool to track tasks.

_Why? You may ask..._
_I learned Haskell and played around with it._

## Help ?

```
$ todo --help
USAGE: todo [...<arguments>]

  todo --help
  todo -h
       Print this help message

  todo <id> <task> <due>
  todo <id> <due>
  todo <id> <task>
       Update a task with new <task> description and/or <due> date

  todo <id>
       Mark a task as done, just now

  todo <task> <due>
  todo <task>
       Register a new <task>, eventually with a <due> date

  todo ? <terms>
  todo ?
  todo
       List pending tasks, eventually filtered by <terms>, sorted by due date

API NOTES:
- <id> must be a 1+ integer
- Once done, a task cannot be undone
- <task> as blank strings are invalid
- <due> date cannot be unset after it has been set
- <due> must be ISO 8601 date or duration, e.g. '2026-03-06T12:00:00Z' or 'P3DT12H'
- <id> is printed to the standard output when an update did happen
```

## Examples ?

Add a task:
```
$ todo 'Clean the dishes' PT5H
1
```

List tasks:
```
$ todo
ID  Task              Created                         Due
--  ----------------  ------------------------------  ------------------------------
 1  Clean the dishes  2026-03-06T15:08:04.834995338Z  2026-03-06T20:08:04.834960301Z
```

Add a task with a specific date:
```
$ todo 'Pass driver license' '2026-06-17T17:00:00.0Z'
2

$ todo
ID  Task                 Created                         Due
--  -------------------  ------------------------------  ------------------------------
 1  Clean the dishes     2026-03-06T15:08:04.834995338Z  2026-03-06T20:08:04.834960301Z
 2  Pass driver license  2026-03-06T15:11:02.053891293Z  2026-06-17T17:00:00Z
```

Fuzzy search pending tasks with colored output:
```
$ todo ? cld
ID  Task              Created                         Due
--  ----------------  ------------------------------  ------------------------------
 1  Clean the dishes  2026-03-06T15:08:04.834995338Z  2026-03-06T20:08:04.834960301Z
```

## What Next?

+ [ ] Track overdue ration
+ [ ] Track distance between decision and action


## License

MIT License or whatever is the most permissible thing you know/want/can-think-of.
