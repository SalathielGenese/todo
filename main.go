package main

import (
	"os"
	"todo.salathiel.genese.name/domain"
)

func main() {
	for command := range domain.Run(os.Stdin, os.Args[1:]) {
		command.Execute()
	}
}
