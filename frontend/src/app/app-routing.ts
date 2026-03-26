import { Routes } from '@angular/router';
import { authGuard } from './guards/auth.guard';

export const routes: Routes = [
  {
    path: '',
    loadComponent: () =>
      import('./components/home/home.component').then(m => m.HomeComponent)
  },
  {
    path: 'products',
    loadComponent: () =>
      import('./components/products/product-list/product-list.component').then(
        m => m.ProductListComponent
      )
  },
  {
    path: 'products/:id',
    loadComponent: () =>
      import('./components/products/product-detail/product-detail.component').then(
        m => m.ProductDetailComponent
      )
  },
  {
    path: 'cart',
    loadComponent: () =>
      import('./components/cart/cart.component').then(m => m.CartComponent)
  },
  {
    path: 'checkout',
    canActivate: [authGuard],
    loadComponent: () =>
      import('./components/checkout/checkout.component').then(m => m.CheckoutComponent)
  },
  {
    path: 'orders',
    canActivate: [authGuard],
    loadComponent: () =>
      import('./components/orders/order-history/order-history.component').then(
        m => m.OrderHistoryComponent
      )
  },
  {
    path: 'auth',
    children: [
      {
        path: 'login',
        loadComponent: () =>
          import('./components/auth/login/login.component').then(m => m.LoginComponent)
      },
      {
        path: 'register',
        loadComponent: () =>
          import('./components/auth/register/register.component').then(
            m => m.RegisterComponent
          )
      }
    ]
  },
  { path: '**', redirectTo: '' }
];
