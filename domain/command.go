package domain

type Command interface {
	Execute(tasks *[]Task) *Command
}

type CommandMenu struct{}
type CommandDelete struct {
	Id string
}
type CommandComplete struct {
	Id string
}
type CommandSearch struct {
	DueAt, Filter, Paranoid *string
}
type CommandEdit struct {
	Id                        string
	Title, DueAt, Description *string
}

func (self CommandComplete) Execute(tasks *[]Task) *Command {
	return nil
}
func (self CommandDelete) Execute(tasks *[]Task) *Command {
	return nil
}
func (self CommandSearch) Execute(tasks *[]Task) *Command {
	return nil
}
func (self CommandEdit) Execute(tasks *[]Task) *Command {
	return nil
}
func (self CommandMenu) Execute(tasks *[]Task) *Command {
	return nil
}
