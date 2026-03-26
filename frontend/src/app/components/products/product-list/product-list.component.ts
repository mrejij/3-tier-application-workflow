import { Component, OnInit, inject, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ProductService } from '../../../services/product.service';
import { CartService } from '../../../services/cart.service';
import { Product, Category, ProductFilter } from '../../../models/product.model';

@Component({
  selector: 'app-product-list',
  standalone: true,
  imports: [RouterLink, CommonModule, FormsModule],
  template: `
    <div class="container py-4">
      <div class="row g-4">
        <!-- Sidebar Filters -->
        <aside class="col-md-3">
          <div class="card p-3">
            <h5 class="mb-3">Filters</h5>

            <!-- Category -->
            <div class="mb-3">
              <label class="form-label fw-semibold">Category</label>
              <select class="form-select form-select-sm" [(ngModel)]="filter.categoryId"
                      (change)="applyFilters()">
                <option [value]="undefined">All Categories</option>
                @for (cat of categories(); track cat.id) {
                  <option [value]="cat.id">{{ cat.name }}</option>
                }
              </select>
            </div>

            <!-- Price Range -->
            <div class="mb-3">
              <label class="form-label fw-semibold">Price Range</label>
              <div class="d-flex gap-2">
                <input type="number" class="form-control form-control-sm" placeholder="Min"
                       [(ngModel)]="filter.minPrice" (change)="applyFilters()" />
                <input type="number" class="form-control form-control-sm" placeholder="Max"
                       [(ngModel)]="filter.maxPrice" (change)="applyFilters()" />
              </div>
            </div>

            <!-- Sort -->
            <div class="mb-3">
              <label class="form-label fw-semibold">Sort By</label>
              <select class="form-select form-select-sm" [(ngModel)]="filter.sortBy"
                      (change)="applyFilters()">
                <option value="createdAt">Newest</option>
                <option value="price">Price</option>
                <option value="rating">Rating</option>
                <option value="name">Name</option>
              </select>
            </div>

            <button class="btn btn-outline-secondary btn-sm w-100" (click)="resetFilters()">
              Reset Filters
            </button>
          </div>
        </aside>

        <!-- Product Grid -->
        <div class="col-md-9">
          <!-- Search bar -->
          <div class="input-group mb-4">
            <input type="search" class="form-control" placeholder="Search products..."
                   [(ngModel)]="filter.searchTerm" (keyup.enter)="applyFilters()" />
            <button class="btn btn-primary" (click)="applyFilters()">
              <i class="bi bi-search"></i>
            </button>
          </div>

          @if (loading()) {
            <div class="d-flex justify-content-center py-5">
              <div class="spinner-border text-primary"></div>
            </div>
          } @else if (products().length === 0) {
            <div class="text-center py-5">
              <i class="bi bi-search display-1 text-muted"></i>
              <p class="mt-3 text-muted">No products found. Try different filters.</p>
            </div>
          } @else {
            <div class="product-grid">
              @for (product of products(); track product.id) {
                <div class="card p-3">
                  <a [routerLink]="['/products', product.id]">
                    <img [src]="product.imageUrl" [alt]="product.name"
                         class="w-100 mb-2" style="height:160px;object-fit:contain;" />
                  </a>
                  <h6 class="mb-1 text-truncate" [title]="product.name">{{ product.name }}</h6>
                  <small class="text-muted">{{ product.categoryName }}</small>
                  <div class="d-flex align-items-center gap-2 mt-1">
                    <span class="price">{{ product.discountPrice ?? product.price | currency }}</span>
                    @if (product.discountPrice) {
                      <span class="price-original">{{ product.price | currency }}</span>
                    }
                  </div>
                  <div class="mt-2 d-flex gap-2">
                    <a [routerLink]="['/products', product.id]"
                       class="btn btn-outline-primary btn-sm flex-fill">Details</a>
                    <button class="btn btn-primary btn-sm flex-fill"
                            (click)="addToCart(product)"
                            [disabled]="product.stockQuantity === 0">
                      {{ product.stockQuantity === 0 ? 'Out of Stock' : 'Add to Cart' }}
                    </button>
                  </div>
                </div>
              }
            </div>

            <!-- Pagination -->
            @if (totalPages() > 1) {
              <nav class="mt-4 d-flex justify-content-center">
                <ul class="pagination">
                  <li class="page-item" [class.disabled]="filter.pageNumber === 1">
                    <button class="page-link" (click)="goToPage(filter.pageNumber - 1)">Prev</button>
                  </li>
                  @for (p of pageNumbers(); track p) {
                    <li class="page-item" [class.active]="p === filter.pageNumber">
                      <button class="page-link" (click)="goToPage(p)">{{ p }}</button>
                    </li>
                  }
                  <li class="page-item" [class.disabled]="filter.pageNumber === totalPages()">
                    <button class="page-link" (click)="goToPage(filter.pageNumber + 1)">Next</button>
                  </li>
                </ul>
              </nav>
            }
          }
        </div>
      </div>
    </div>
  `
})
export class ProductListComponent implements OnInit {
  private productService = inject(ProductService);
  private cartService = inject(CartService);
  private route = inject(ActivatedRoute);

  loading = signal(true);
  products = signal<Product[]>([]);
  categories = signal<Category[]>([]);
  totalPages = signal(1);
  pageNumbers = signal<number[]>([]);

  filter: ProductFilter = {
    pageNumber: 1,
    pageSize: 12,
    sortBy: 'createdAt',
    sortDirection: 'desc'
  };

  ngOnInit(): void {
    this.productService.getCategories().subscribe(cats => this.categories.set(cats));
    this.route.queryParams.subscribe(params => {
      if (params['categoryId']) this.filter.categoryId = +params['categoryId'];
      this.loadProducts();
    });
  }

  loadProducts(): void {
    this.loading.set(true);
    this.productService.getProducts(this.filter).subscribe({
      next: result => {
        this.products.set(result.items);
        this.totalPages.set(result.totalPages);
        this.pageNumbers.set(Array.from({ length: result.totalPages }, (_, i) => i + 1));
        this.loading.set(false);
      },
      error: () => this.loading.set(false)
    });
  }

  applyFilters(): void {
    this.filter.pageNumber = 1;
    this.loadProducts();
  }

  resetFilters(): void {
    this.filter = { pageNumber: 1, pageSize: 12, sortBy: 'createdAt', sortDirection: 'desc' };
    this.loadProducts();
  }

  goToPage(page: number): void {
    if (page < 1 || page > this.totalPages()) return;
    this.filter.pageNumber = page;
    this.loadProducts();
  }

  addToCart(product: Product): void {
    this.cartService.addToCart({
      productId: product.id,
      productName: product.name,
      productImageUrl: product.imageUrl,
      sku: product.sku,
      unitPrice: product.price,
      discountPrice: product.discountPrice,
      quantity: 1
    });
  }
}
