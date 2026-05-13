package model

type Tag struct {
	Name        string `json:"name" gorm:"primaryKey"`
	DisplayName string `json:"displayName"`
}
