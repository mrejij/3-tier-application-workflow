import { Component, OnInit, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { CommonModule } from '@angular/common';
import { OrderService } from '../../../services/order.service';
import { Order } from '../../../models/order.model';

@Component({
  selector: 'app-order-history',
  standalone: true,
  imports: [RouterLink, CommonModule],
  template: `
    <div class="container py-5" style="max-width:900px;">
      <h2 class="fw-bold mb-4">My Orders</h2>

      @if (loading()) {
        <div class="d-flex justify-content-center py-5">
          <div class="spinner-border text-primary"></div>
        </div>
      } @else if (orders().length === 0) {
        <div class="text-center py-5">
          <i class="bi bi-bag-x display-1 text-muted"></i>
          <p class="mt-3 text-muted">You haven't placed any orders yet.</p>
          <a routerLink="/products" class="btn btn-primary">Start Shopping</a>
        </div>
      } @else {
        @for (order of orders(); track order.id) {
          <div class="card mb-3 p-4">
            <div class="d-flex justify-content-between align-items-center mb-3">
              <div>
                <h6 class="mb-0 fw-bold">Order #{{ order.orderNumber }}</h6>
                <small class="text-muted">
                  {{ order.createdAt | date:'mediumDate' }}
                </small>
              </div>
              <div class="d-flex align-items-center gap-3">
                <span class="badge" [ngClass]="statusClass(order.status)">
                  {{ order.status }}
                </span>
                <span class="fw-bold price">{{ order.total | currency }}</span>
              </div>
            </div>

            <div class="d-flex flex-wrap gap-3">
              @for (item of order.items; track item.productId) {
                <div class="d-flex gap-2 align-items-center border rounded p-2">
                  <span class="fw-semibold">{{ item.productName }}</span>
                  <span class="text-muted small">× {{ item.quantity }}</span>
                  <span class="price small">{{ item.subtotal | currency }}</span>
                </div>
              }
            </div>
          </div>
        }
      }
    </div>
  `
})
export class OrderHistoryComponent implements OnInit {
  private orderService = inject(OrderService);

  loading = signal(true);
  orders = signal<Order[]>([]);

  ngOnInit(): void {
    this.orderService.getMyOrders().subscribe({
      next: result => {
        this.orders.set(result.items);
        this.loading.set(false);
      },
      error: () => this.loading.set(false)
    });
  }

  statusClass(status: string): string {
    const map: Record<string, string> = {
      Pending: 'bg-warning text-dark',
      Processing: 'bg-info text-dark',
      Shipped: 'bg-primary',
      Delivered: 'bg-success',
      Cancelled: 'bg-danger'
    };
    return map[status] ?? 'bg-secondary';
  }
}
