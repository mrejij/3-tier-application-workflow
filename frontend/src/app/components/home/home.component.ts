import { Component, OnInit, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { CommonModule } from '@angular/common';
import { ProductService } from '../../services/product.service';
import { Product, Category } from '../../models/product.model';

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [RouterLink, CommonModule],
  template: `
    <!-- Hero Banner -->
    <section class="bg-primary text-white py-5">
      <div class="container py-4">
        <div class="row align-items-center">
          <div class="col-lg-6">
            <h1 class="display-4 fw-bold">Shop the Latest Trends</h1>
            <p class="lead">Discover thousands of products with unbeatable prices.</p>
            <a routerLink="/products" class="btn btn-light btn-lg mt-2">
              Shop Now <i class="bi bi-arrow-right ms-2"></i>
            </a>
          </div>
        </div>
      </div>
    </section>

    <!-- Categories -->
    <section class="py-5 bg-light">
      <div class="container">
        <h2 class="mb-4 fw-semibold">Shop by Category</h2>
        @if (loading()) {
          <div class="d-flex gap-3">
            @for (i of [1,2,3,4]; track i) {
              <div class="placeholder-glow flex-fill">
                <span class="placeholder w-100" style="height:100px;border-radius:8px;"></span>
              </div>
            }
          </div>
        } @else {
          <div class="row g-3">
            @for (cat of categories(); track cat.id) {
              <div class="col-6 col-md-3">
                <a [routerLink]="['/products']" [queryParams]="{categoryId: cat.id}"
                   class="card text-center p-3 text-decoration-none h-100">
                  <img [src]="cat.imageUrl" [alt]="cat.name"
                       class="rounded-circle mx-auto mb-2"
                       style="width:60px;height:60px;object-fit:cover;" />
                  <h6 class="mb-0">{{ cat.name }}</h6>
                </a>
              </div>
            }
          </div>
        }
      </div>
    </section>

    <!-- Featured Products -->
    <section class="py-5">
      <div class="container">
        <div class="d-flex justify-content-between align-items-center mb-4">
          <h2 class="fw-semibold mb-0">Featured Products</h2>
          <a routerLink="/products" class="btn btn-outline-primary btn-sm">View All</a>
        </div>

        @if (loading()) {
          <div class="product-grid">
            @for (i of [1,2,3,4,5,6]; track i) {
              <div class="card placeholder-glow p-3" style="height:300px;">
                <span class="placeholder w-100 mb-3" style="height:180px;"></span>
                <span class="placeholder w-75 mb-2"></span>
                <span class="placeholder w-50"></span>
              </div>
            }
          </div>
        } @else {
          <div class="product-grid">
            @for (product of featured(); track product.id) {
              <div class="card p-3">
                <a [routerLink]="['/products', product.id]">
                  <img [src]="product.imageUrl" [alt]="product.name"
                       class="w-100 mb-3" style="height:180px;object-fit:contain;" />
                </a>
                <h6 class="mb-1">{{ product.name }}</h6>
                <div class="d-flex align-items-center gap-2">
                  <span class="price">{{ product.discountPrice ?? product.price | currency }}</span>
                  @if (product.discountPrice) {
                    <span class="price-original">{{ product.price | currency }}</span>
                  }
                </div>
                <a [routerLink]="['/products', product.id]"
                   class="btn btn-primary btn-sm mt-2">View Details</a>
              </div>
            }
          </div>
        }
      </div>
    </section>
  `
})
export class HomeComponent implements OnInit {
  private productService = inject(ProductService);

  loading = signal(true);
  featured = signal<Product[]>([]);
  categories = signal<Category[]>([]);

  ngOnInit(): void {
    this.productService.getCategories().subscribe(cats => this.categories.set(cats));
    this.productService.getFeaturedProducts().subscribe({
      next: products => {
        this.featured.set(products);
        this.loading.set(false);
      },
      error: () => this.loading.set(false)
    });
  }
}
