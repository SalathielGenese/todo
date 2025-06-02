package domain

import (
	"reflect"
	"strings"
	"testing"
)

func TestSmartFilter(t *testing.T) {
	type Person struct {
		age  int
		name string
	}
	people := []Person{{age: 52, name: "Farid"}, {age: 34, name: "Renee"}, {age: 25, name: "Faith"}}
	fNamedPeople := []Person{{age: 52, name: "Farid"}, {age: 25, name: "Faith"}}
	over30People := []Person{{age: 52, name: "Farid"}, {age: 34, name: "Renee"}}

	if !reflect.DeepEqual(fNamedPeople, []Person(Smart[Person](people).
		Filter(func(p Person) bool { return strings.HasPrefix(p.name, "F") }))) {
		t.Errorf("Expected filter to only retain people whose name started with 'F'. Got: %v", fNamedPeople)
	}

	if !reflect.DeepEqual(over30People, []Person(Smart[Person](people).
		Filter(func(p Person) bool { return 30 < p.age }))) {
		t.Errorf("Expected filter to only retain people older than 30. Got: %v", over30People)
	}
}
