package domain

type Command interface {
	Execute()
}

type CommandMenu struct {
	channel chan<- Command
}
type CommandAdd struct {
	Title              string
	DueAt, Description *string
}
type CommandHelp struct {
	Reason string
}
type CommandEdit struct {
	Id                        string
	Title, DueAt, Description *string
}
type CommandSearch struct {
	DueAt, Filter, Paranoid *string
}
type CommandDelete struct {
	Id string
}
type CommandComplete struct {
	Id string
}

func (self CommandComplete) Execute() {
}
func (self CommandDelete) Execute() {
}
func (self CommandSearch) Execute() {
}
func (self CommandEdit) Execute() {
}
func (self CommandMenu) Execute() {
}
func (self CommandHelp) Execute() {
}
func (self CommandAdd) Execute() {
}
