import { Component, OnInit, inject, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ProductService } from '../../../services/product.service';
import { CartService } from '../../../services/cart.service';
import { Product } from '../../../models/product.model';

@Component({
  selector: 'app-product-detail',
  standalone: true,
  imports: [RouterLink, CommonModule, FormsModule],
  template: `
    <div class="container py-5">
      @if (loading()) {
        <div class="d-flex justify-content-center py-5">
          <div class="spinner-border text-primary"></div>
        </div>
      } @else if (product()) {
        <nav aria-label="breadcrumb" class="mb-4">
          <ol class="breadcrumb">
            <li class="breadcrumb-item"><a routerLink="/">Home</a></li>
            <li class="breadcrumb-item"><a routerLink="/products">Products</a></li>
            <li class="breadcrumb-item active">{{ product()!.name }}</li>
          </ol>
        </nav>

        <div class="row g-5">
          <!-- Image -->
          <div class="col-md-5">
            <div class="card p-4 text-center">
              <img [src]="product()!.imageUrl" [alt]="product()!.name"
                   class="img-fluid" style="max-height:350px;object-fit:contain;" />
            </div>
          </div>

          <!-- Info -->
          <div class="col-md-7">
            <span class="badge bg-secondary mb-2">{{ product()!.categoryName }}</span>
            <h2 class="fw-bold">{{ product()!.name }}</h2>
            <p class="text-muted small">SKU: {{ product()!.sku }}</p>

            <!-- Price -->
            <div class="d-flex align-items-center gap-3 mb-3">
              <span class="fs-3 price">
                {{ product()!.discountPrice ?? product()!.price | currency }}
              </span>
              @if (product()!.discountPrice) {
                <span class="price-original fs-5">{{ product()!.price | currency }}</span>
                <span class="badge bg-danger">
                  {{ discount() }}% OFF
                </span>
              }
            </div>

            <!-- Stock -->
            @if (product()!.stockQuantity > 0) {
              <span class="badge bg-success mb-3">In Stock ({{ product()!.stockQuantity }} left)</span>
            } @else {
              <span class="badge bg-danger mb-3">Out of Stock</span>
            }

            <p class="text-muted">{{ product()!.description }}</p>

            <!-- Quantity & Add to Cart -->
            @if (product()!.stockQuantity > 0) {
              <div class="d-flex align-items-center gap-3 mt-3">
                <div class="input-group" style="width:120px;">
                  <button class="btn btn-outline-secondary" type="button"
                          (click)="quantity > 1 && quantity--">-</button>
                  <input type="number" class="form-control text-center" [(ngModel)]="quantity"
                         min="1" [max]="product()!.stockQuantity" />
                  <button class="btn btn-outline-secondary" type="button"
                          (click)="quantity < product()!.stockQuantity && quantity++">+</button>
                </div>
                <button class="btn btn-primary px-4" (click)="addToCart()">
                  <i class="bi bi-cart-plus me-2"></i>Add to Cart
                </button>
              </div>
            }

            @if (addedToCart()) {
              <div class="alert alert-success mt-3 py-2">
                Added to cart! <a routerLink="/cart">View Cart</a>
              </div>
            }
          </div>
        </div>
      } @else {
        <div class="text-center py-5">
          <p class="text-muted">Product not found.</p>
          <a routerLink="/products" class="btn btn-primary">Back to Products</a>
        </div>
      }
    </div>
  `
})
export class ProductDetailComponent implements OnInit {
  private productService = inject(ProductService);
  private cartService = inject(CartService);
  private route = inject(ActivatedRoute);

  loading = signal(true);
  product = signal<Product | null>(null);
  addedToCart = signal(false);
  quantity = 1;

  discount = () => {
    const p = this.product();
    if (!p?.discountPrice) return 0;
    return Math.round(((p.price - p.discountPrice) / p.price) * 100);
  };

  ngOnInit(): void {
    const id = +this.route.snapshot.paramMap.get('id')!;
    this.productService.getProductById(id).subscribe({
      next: p => { this.product.set(p); this.loading.set(false); },
      error: () => this.loading.set(false)
    });
  }

  addToCart(): void {
    const p = this.product()!;
    this.cartService.addToCart({
      productId: p.id,
      productName: p.name,
      productImageUrl: p.imageUrl,
      sku: p.sku,
      unitPrice: p.price,
      discountPrice: p.discountPrice,
      quantity: this.quantity
    });
    this.addedToCart.set(true);
    setTimeout(() => this.addedToCart.set(false), 3000);
  }
}
