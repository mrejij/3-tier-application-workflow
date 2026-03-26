import { Injectable, signal, computed } from '@angular/core';
import { Cart, CartItem, emptyCart } from '../models/cart.model';

const CART_KEY = 'ecommerce_cart';

@Injectable({ providedIn: 'root' })
export class CartService {
  private _cart = signal<Cart>(this.loadFromStorage());

  readonly cart = this._cart.asReadonly();
  readonly itemCount = computed(() => this._cart().totalItems);
  readonly cartTotal = computed(() => this._cart().total);

  addToCart(item: Omit<CartItem, 'subtotal'>): void {
    const cart = { ...this._cart() };
    const existing = cart.items.find(i => i.productId === item.productId);

    if (existing) {
      existing.quantity += item.quantity;
      existing.subtotal = (item.discountPrice ?? item.unitPrice) * existing.quantity;
    } else {
      cart.items.push({
        ...item,
        subtotal: (item.discountPrice ?? item.unitPrice) * item.quantity
      });
    }

    this.recalculate(cart);
  }

  updateQuantity(productId: number, quantity: number): void {
    const cart = { ...this._cart() };
    const item = cart.items.find(i => i.productId === productId);
    if (!item) return;

    if (quantity <= 0) {
      this.removeItem(productId);
      return;
    }

    item.quantity = quantity;
    item.subtotal = (item.discountPrice ?? item.unitPrice) * quantity;
    this.recalculate(cart);
  }

  removeItem(productId: number): void {
    const cart = { ...this._cart() };
    cart.items = cart.items.filter(i => i.productId !== productId);
    this.recalculate(cart);
  }

  clearCart(): void {
    this._cart.set({ ...emptyCart, items: [] });
    this.saveToStorage(this._cart());
  }

  private recalculate(cart: Cart): void {
    cart.subtotal = cart.items.reduce((sum, i) => sum + i.subtotal, 0);
    cart.totalItems = cart.items.reduce((sum, i) => sum + i.quantity, 0);
    cart.total = cart.subtotal - cart.discount;
    this._cart.set(cart);
    this.saveToStorage(cart);
  }

  private loadFromStorage(): Cart {
    try {
      const stored = localStorage.getItem(CART_KEY);
      return stored ? (JSON.parse(stored) as Cart) : { ...emptyCart, items: [] };
    } catch {
      return { ...emptyCart, items: [] };
    }
  }

  private saveToStorage(cart: Cart): void {
    localStorage.setItem(CART_KEY, JSON.stringify(cart));
  }
}
