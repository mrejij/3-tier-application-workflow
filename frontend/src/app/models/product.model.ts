export interface Product {
  id: number;
  name: string;
  description: string;
  price: number;
  discountPrice?: number;
  imageUrl: string;
  categoryId: number;
  categoryName: string;
  stockQuantity: number;
  sku: string;
  rating: number;
  reviewCount: number;
  isActive: boolean;
  createdAt: string;
}

export interface Category {
  id: number;
  name: string;
  description: string;
  imageUrl: string;
}

export interface ProductFilter {
  categoryId?: number;
  minPrice?: number;
  maxPrice?: number;
  searchTerm?: string;
  pageNumber: number;
  pageSize: number;
  sortBy?: string;
  sortDirection?: 'asc' | 'desc';
}

export interface PagedResult<T> {
  items: T[];
  totalCount: number;
  pageNumber: number;
  pageSize: number;
  totalPages: number;
  hasPreviousPage: boolean;
  hasNextPage: boolean;
}
