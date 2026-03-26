import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import { Order, CreateOrderRequest, PagedResult } from '../models/order.model';
import { PagedResult as PR } from '../models/product.model';

@Injectable({ providedIn: 'root' })
export class OrderService {
  private readonly base = `${environment.apiUrl}/orders`;

  constructor(private http: HttpClient) {}

  placeOrder(request: CreateOrderRequest): Observable<Order> {
    return this.http.post<Order>(this.base, request);
  }

  getMyOrders(pageNumber = 1, pageSize = 10): Observable<PR<Order>> {
    return this.http.get<PR<Order>>(`${this.base}/my-orders`, {
      params: { pageNumber, pageSize }
    });
  }

  getOrderById(id: number): Observable<Order> {
    return this.http.get<Order>(`${this.base}/${id}`);
  }

  getOrderByNumber(orderNumber: string): Observable<Order> {
    return this.http.get<Order>(`${this.base}/track/${orderNumber}`);
  }

  cancelOrder(id: number): Observable<void> {
    return this.http.patch<void>(`${this.base}/${id}/cancel`, {});
  }
}
