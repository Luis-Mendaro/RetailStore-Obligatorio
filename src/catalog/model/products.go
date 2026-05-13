package model

type Product struct {
	ID          string `json:"id" gorm:"primaryKey"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Price       int    `json:"price"`
	Tags        []Tag  `json:"tags" gorm:"many2many:product_tags;"`
}

type CatalogSizeResponse struct {
	Size int `json:"size"`
}
