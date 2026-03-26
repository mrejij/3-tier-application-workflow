import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import { Product, Category, ProductFilter, PagedResult } from '../models/product.model';

@Injectable({ providedIn: 'root' })
export class ProductService {
  private readonly base = `${environment.apiUrl}/products`;

  constructor(private http: HttpClient) {}

  getProducts(filter: ProductFilter): Observable<PagedResult<Product>> {
    let params = new HttpParams()
      .set('pageNumber', filter.pageNumber)
      .set('pageSize', filter.pageSize);

    if (filter.categoryId) params = params.set('categoryId', filter.categoryId);
    if (filter.minPrice !== undefined) params = params.set('minPrice', filter.minPrice);
    if (filter.maxPrice !== undefined) params = params.set('maxPrice', filter.maxPrice);
    if (filter.searchTerm) params = params.set('searchTerm', filter.searchTerm);
    if (filter.sortBy) params = params.set('sortBy', filter.sortBy);
    if (filter.sortDirection) params = params.set('sortDirection', filter.sortDirection);

    return this.http.get<PagedResult<Product>>(this.base, { params });
  }

  getProductById(id: number): Observable<Product> {
    return this.http.get<Product>(`${this.base}/${id}`);
  }

  getFeaturedProducts(): Observable<Product[]> {
    return this.http.get<Product[]>(`${this.base}/featured`);
  }

  getCategories(): Observable<Category[]> {
    return this.http.get<Category[]>(`${environment.apiUrl}/categories`);
  }

  searchProducts(term: string): Observable<Product[]> {
    const params = new HttpParams().set('q', term);
    return this.http.get<Product[]>(`${this.base}/search`, { params });
  }
}
