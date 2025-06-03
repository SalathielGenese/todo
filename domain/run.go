package domain

import (
	"os"
	"strings"
)

func Run(reader *os.File, arguments []string) <-chan Command {
	args, channel := Smart[string](arguments), make(chan Command, 1)
	go func() {
		switch {
		case 0 == len(args):
			channel <- CommandMenu{channel: channel}

		case 0 < len(args.Filter(func(a string) bool { return "-h" == a || "--help" == a })):
			defer close(channel)
			channel <- CommandHelp{}

		default:
			defer close(channel)
			var id, dueAt, title, filter, paranoid, description *string

			if i := args.IndexOf(func(i string) bool { return "-p" == i || "--paranoid" == i }); -1 < i {
				v := "true"
				paranoid = &v
			}
			if i := args.IndexOf(func(i string) bool { return "-i" == i || "--id" == i }); -1 < i && i+1 < len(args) {
				id = &args[i+1]
			}
			if i := args.IndexOf(func(i string) bool { return "-t" == i || "--title" == i }); -1 < i && i+1 < len(args) {
				title = &args[i+1]
			}
			if i := args.IndexOf(func(i string) bool { return "-f" == i || "--filter" == i }); -1 < i && i+1 < len(args) {
				filter = &args[i+1]
			}
			if i := args.IndexOf(func(i string) bool { return "-d" == i || "--due-at" == i }); -1 < i && i+1 < len(args) {
				dueAt = &args[i+1]
			}

			switch strings.ToLower(args[0]) {
			case "complete":
				switch id {
				case nil:
					channel <- CommandHelp{Reason: "[complete] -i|--id<id> is mandatory"}
				default:
					channel <- CommandComplete{Id: *id}
				}
			case "delete":
				switch id {
				case nil:
					channel <- CommandHelp{Reason: "[delete] -i|--id <id> is mandatory"}
				default:
					channel <- CommandDelete{Id: *id}
				}
			case "search":
				channel <- CommandSearch{DueAt: dueAt, Filter: filter, Paranoid: paranoid}
			case "edit":
				switch id {
				case nil:
					channel <- CommandHelp{Reason: "[edit] -i|--id <id> is mandatory"}
				default:
					channel <- CommandEdit{Id: *id, Title: title, DueAt: dueAt, Description: description}
				}
			case "add":
				switch title {
				case nil:
					channel <- CommandHelp{Reason: "[add] -t|--title <title> is mandatory"}
				default:
					channel <- CommandAdd{Title: *title, DueAt: dueAt, Description: description}
				}

			default:
				channel <- CommandHelp{Reason: "misuse"}
			}
		}
	}()
	return channel
}
