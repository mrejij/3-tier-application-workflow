export interface CartItem {
  productId: number;
  productName: string;
  productImageUrl: string;
  sku: string;
  unitPrice: number;
  discountPrice?: number;
  quantity: number;
  subtotal: number;
}

export interface Cart {
  items: CartItem[];
  totalItems: number;
  subtotal: number;
  discount: number;
  total: number;
}

export const emptyCart: Cart = {
  items: [],
  totalItems: 0,
  subtotal: 0,
  discount: 0,
  total: 0
};
