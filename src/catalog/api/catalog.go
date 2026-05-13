package api

import (
	"context"

	"retail-store/catalog/model"
	"retail-store/catalog/repository"
)

// CatalogAPI type
type CatalogAPI struct {
	repository repository.CatalogRepository
}

func (a *CatalogAPI) GetProducts(tags []string, order string, pageNum, pageSize int, ctx context.Context) ([]model.Product, error) {
	products, err := a.repository.GetProducts(tags, order, pageNum, pageSize, ctx)
	if err != nil {
		return nil, err
	}
	return products, nil
}

func (a *CatalogAPI) GetProduct(id string, ctx context.Context) (*model.Product, error) {
	return a.repository.GetProduct(id, ctx)
}

func (a *CatalogAPI) GetTags(ctx context.Context) ([]model.Tag, error) {
	return a.repository.GetTags(ctx)
}

func (a *CatalogAPI) GetSize(tags []string, ctx context.Context) (int, error) {
	return a.repository.CountProducts(tags, ctx)
}

// NewCatalogAPI constructor
func NewCatalogAPI(repository repository.CatalogRepository) (*CatalogAPI, error) {
	return &CatalogAPI{
		repository: repository,
	}, nil
}
