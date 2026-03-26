import { Component, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { CommonModule } from '@angular/common';
import { CartService } from '../../services/cart.service';

@Component({
  selector: 'app-cart',
  standalone: true,
  imports: [RouterLink, CommonModule],
  template: `
    <div class="container py-5" style="max-width:900px;">
      <h2 class="fw-bold mb-4">Shopping Cart</h2>

      @if (cartService.cart().items.length === 0) {
        <div class="text-center py-5">
          <i class="bi bi-cart-x display-1 text-muted"></i>
          <p class="mt-3 text-muted">Your cart is empty.</p>
          <a routerLink="/products" class="btn btn-primary">Continue Shopping</a>
        </div>
      } @else {
        <div class="row g-4">
          <!-- Items -->
          <div class="col-md-8">
            @for (item of cartService.cart().items; track item.productId) {
              <div class="card p-3 mb-3">
                <div class="d-flex gap-3 align-items-center">
                  <img [src]="item.productImageUrl" [alt]="item.productName"
                       style="width:80px;height:80px;object-fit:contain;" />
                  <div class="flex-fill">
                    <h6 class="mb-1">{{ item.productName }}</h6>
                    <small class="text-muted">SKU: {{ item.sku }}</small>
                    <div class="price mt-1">{{ item.discountPrice ?? item.unitPrice | currency }}</div>
                  </div>
                  <div class="d-flex align-items-center gap-2">
                    <div class="input-group" style="width:110px;">
                      <button class="btn btn-outline-secondary btn-sm"
                              (click)="cartService.updateQuantity(item.productId, item.quantity - 1)">
                        -
                      </button>
                      <span class="form-control form-control-sm text-center">{{ item.quantity }}</span>
                      <button class="btn btn-outline-secondary btn-sm"
                              (click)="cartService.updateQuantity(item.productId, item.quantity + 1)">
                        +
                      </button>
                    </div>
                    <span class="fw-bold" style="min-width:80px;text-align:right;">
                      {{ item.subtotal | currency }}
                    </span>
                    <button class="btn btn-link text-danger p-0"
                            (click)="cartService.removeItem(item.productId)">
                      <i class="bi bi-trash"></i>
                    </button>
                  </div>
                </div>
              </div>
            }
            <div class="d-flex justify-content-between">
              <a routerLink="/products" class="btn btn-outline-secondary">
                <i class="bi bi-arrow-left me-2"></i>Continue Shopping
              </a>
              <button class="btn btn-outline-danger btn-sm" (click)="cartService.clearCart()">
                Clear Cart
              </button>
            </div>
          </div>

          <!-- Summary -->
          <div class="col-md-4">
            <div class="card p-4">
              <h5 class="fw-bold mb-3">Order Summary</h5>
              <div class="d-flex justify-content-between mb-2">
                <span>Subtotal ({{ cartService.cart().totalItems }} items)</span>
                <span>{{ cartService.cart().subtotal | currency }}</span>
              </div>
              @if (cartService.cart().discount > 0) {
                <div class="d-flex justify-content-between mb-2 text-success">
                  <span>Discount</span>
                  <span>-{{ cartService.cart().discount | currency }}</span>
                </div>
              }
              <hr />
              <div class="d-flex justify-content-between fw-bold fs-5 mb-3">
                <span>Total</span>
                <span class="price">{{ cartService.cartTotal() | currency }}</span>
              </div>
              <a routerLink="/checkout" class="btn btn-primary w-100">
                Proceed to Checkout <i class="bi bi-arrow-right ms-2"></i>
              </a>
            </div>
          </div>
        </div>
      }
    </div>
  `
})
export class CartComponent {
  readonly cartService = inject(CartService);
}
