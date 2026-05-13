export interface ExistingOrder {
  id?: string;
  shippingAddress?: {
    firstName?: string;
    lastName?: string;
    email?: string;
    address1?: string;
    address2?: string;
    city?: string;
    zipCode?: string;
    state?: string;
  };
  items?: Array<{
    price?: number;
    productId?: string;
    quantity?: number;
    totalCost?: number;
    name?: string;
  }>;
  createdDate?: Date;
}
