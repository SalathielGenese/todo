package domain

import (
	"slices"
	"time"
)

type Task struct {
	Id                            int64
	Title                         string
	Description                   *string
	CreatedAt, UpdatedAt          time.Time
	DueAt, DeletedAt, CompletedAt *time.Time
}

type Smart[T any] []T

func (self Smart[T]) IndexOf(filter func(item T) bool) int {
	return slices.IndexFunc(self, filter)
}

func (self Smart[T]) Filter(filter func(item T) bool) Smart[T] {
	items := []T{}

	for _, item := range self {
		if filter(item) {
			items = append(items, item)
		}
	}

	return items
}
