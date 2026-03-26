import { Component, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { CommonModule } from '@angular/common';
import { AuthService } from '../../services/auth.service';
import { CartService } from '../../services/cart.service';

@Component({
  selector: 'app-navbar',
  standalone: true,
  imports: [RouterLink, CommonModule],
  template: `
    <nav class="navbar navbar-expand-lg navbar-dark bg-primary sticky-top shadow">
      <div class="container">
        <a class="navbar-brand fw-bold" routerLink="/">
          <i class="bi bi-shop me-2"></i>ShopMart
        </a>

        <button class="navbar-toggler" type="button" data-bs-toggle="collapse"
                data-bs-target="#navbarNav">
          <span class="navbar-toggler-icon"></span>
        </button>

        <div class="collapse navbar-collapse" id="navbarNav">
          <ul class="navbar-nav me-auto">
            <li class="nav-item">
              <a class="nav-link" routerLink="/products">Products</a>
            </li>
          </ul>

          <ul class="navbar-nav align-items-center gap-2">
            <!-- Cart -->
            <li class="nav-item">
              <a class="nav-link position-relative" routerLink="/cart">
                <i class="bi bi-cart3 fs-5"></i>
                @if (cartService.itemCount() > 0) {
                  <span class="cart-badge">{{ cartService.itemCount() }}</span>
                }
              </a>
            </li>

            <!-- Auth -->
            @if (authService.isLoggedIn()) {
              <li class="nav-item dropdown">
                <a class="nav-link dropdown-toggle" href="#" data-bs-toggle="dropdown">
                  {{ authService.currentUser()?.firstName }}
                </a>
                <ul class="dropdown-menu dropdown-menu-end">
                  <li><a class="dropdown-item" routerLink="/orders">My Orders</a></li>
                  <li><hr class="dropdown-divider" /></li>
                  <li>
                    <button class="dropdown-item text-danger"
                            (click)="authService.logout()">Sign Out</button>
                  </li>
                </ul>
              </li>
            } @else {
              <li class="nav-item">
                <a class="btn btn-outline-light btn-sm" routerLink="/auth/login">Sign In</a>
              </li>
              <li class="nav-item">
                <a class="btn btn-light btn-sm" routerLink="/auth/register">Register</a>
              </li>
            }
          </ul>
        </div>
      </div>
    </nav>
  `
})
export class NavbarComponent {
  readonly authService = inject(AuthService);
  readonly cartService = inject(CartService);
}
