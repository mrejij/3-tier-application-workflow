import { Component, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { CartService } from '../../services/cart.service';
import { OrderService } from '../../services/order.service';
import { CreateOrderRequest } from '../../models/order.model';

@Component({
  selector: 'app-checkout',
  standalone: true,
  imports: [RouterLink, CommonModule, ReactiveFormsModule],
  template: `
    <div class="container py-5" style="max-width:900px;">
      <h2 class="fw-bold mb-4">Checkout</h2>

      @if (placed()) {
        <div class="card p-5 text-center">
          <i class="bi bi-check-circle-fill display-1 text-success"></i>
          <h3 class="mt-3">Order Placed Successfully!</h3>
          <p class="text-muted">Order #{{ orderNumber() }} has been confirmed.</p>
          <div class="d-flex gap-3 justify-content-center mt-3">
            <a routerLink="/orders" class="btn btn-primary">View Orders</a>
            <a routerLink="/products" class="btn btn-outline-secondary">Continue Shopping</a>
          </div>
        </div>
      } @else {
        <div class="row g-4">
          <!-- Shipping form -->
          <div class="col-md-7">
            <div class="card p-4">
              <h5 class="fw-bold mb-3">Shipping Address</h5>
              <form [formGroup]="form" (ngSubmit)="submitOrder()">
                <div class="row g-3">
                  <div class="col-12">
                    <label class="form-label">Full Name *</label>
                    <input class="form-control" formControlName="fullName" />
                    @if (form.get('fullName')?.invalid && form.get('fullName')?.touched) {
                      <div class="invalid-feedback d-block">Full name is required</div>
                    }
                  </div>
                  <div class="col-12">
                    <label class="form-label">Address Line 1 *</label>
                    <input class="form-control" formControlName="addressLine1" />
                  </div>
                  <div class="col-12">
                    <label class="form-label">Address Line 2</label>
                    <input class="form-control" formControlName="addressLine2" />
                  </div>
                  <div class="col-md-6">
                    <label class="form-label">City *</label>
                    <input class="form-control" formControlName="city" />
                  </div>
                  <div class="col-md-3">
                    <label class="form-label">State *</label>
                    <input class="form-control" formControlName="state" />
                  </div>
                  <div class="col-md-3">
                    <label class="form-label">Postal Code *</label>
                    <input class="form-control" formControlName="postalCode" />
                  </div>
                  <div class="col-md-6">
                    <label class="form-label">Country *</label>
                    <input class="form-control" formControlName="country" />
                  </div>
                  <div class="col-md-6">
                    <label class="form-label">Phone *</label>
                    <input class="form-control" type="tel" formControlName="phone" />
                  </div>
                  <div class="col-12">
                    <label class="form-label fw-semibold">Payment Method</label>
                    <select class="form-select" formControlName="paymentMethod">
                      <option value="CreditCard">Credit Card (demo)</option>
                      <option value="COD">Cash on Delivery</option>
                    </select>
                  </div>
                </div>

                @if (error()) {
                  <div class="alert alert-danger mt-3">{{ error() }}</div>
                }

                <button type="submit" class="btn btn-primary w-100 mt-4"
                        [disabled]="form.invalid || submitting()">
                  @if (submitting()) {
                    <span class="spinner-border spinner-border-sm me-2"></span>
                  }
                  Place Order — {{ cartService.cartTotal() | currency }}
                </button>
              </form>
            </div>
          </div>

          <!-- Summary -->
          <div class="col-md-5">
            <div class="card p-4">
              <h5 class="fw-bold mb-3">Order Summary</h5>
              @for (item of cartService.cart().items; track item.productId) {
                <div class="d-flex justify-content-between mb-2 small">
                  <span>{{ item.productName }} × {{ item.quantity }}</span>
                  <span>{{ item.subtotal | currency }}</span>
                </div>
              }
              <hr />
              <div class="d-flex justify-content-between fw-bold">
                <span>Total</span>
                <span class="price">{{ cartService.cartTotal() | currency }}</span>
              </div>
            </div>
          </div>
        </div>
      }
    </div>
  `
})
export class CheckoutComponent {
  private fb = inject(FormBuilder);
  private orderService = inject(OrderService);
  private router = inject(Router);
  readonly cartService = inject(CartService);

  submitting = signal(false);
  placed = signal(false);
  orderNumber = signal('');
  error = signal('');

  form = this.fb.group({
    fullName: ['', Validators.required],
    addressLine1: ['', Validators.required],
    addressLine2: [''],
    city: ['', Validators.required],
    state: ['', Validators.required],
    postalCode: ['', Validators.required],
    country: ['', Validators.required],
    phone: ['', Validators.required],
    paymentMethod: ['CreditCard', Validators.required]
  });

  submitOrder(): void {
    if (this.form.invalid) return;
    this.submitting.set(true);
    this.error.set('');

    const v = this.form.value;
    const request: CreateOrderRequest = {
      shippingAddress: {
        fullName: v.fullName!,
        addressLine1: v.addressLine1!,
        addressLine2: v.addressLine2 ?? undefined,
        city: v.city!,
        state: v.state!,
        postalCode: v.postalCode!,
        country: v.country!,
        phone: v.phone!
      },
      paymentMethod: v.paymentMethod!
    };

    this.orderService.placeOrder(request).subscribe({
      next: order => {
        this.cartService.clearCart();
        this.orderNumber.set(order.orderNumber);
        this.placed.set(true);
        this.submitting.set(false);
      },
      error: () => {
        this.error.set('Failed to place order. Please try again.');
        this.submitting.set(false);
      }
    });
  }
}
