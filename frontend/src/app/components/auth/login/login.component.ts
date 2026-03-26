import { Component, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { AuthService } from '../../../services/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [RouterLink, CommonModule, ReactiveFormsModule],
  template: `
    <div class="d-flex justify-content-center align-items-center" style="min-height:80vh;">
      <div class="card p-4 shadow" style="width:100%;max-width:420px;">
        <h3 class="fw-bold text-center mb-4">Sign In</h3>

        @if (error()) {
          <div class="alert alert-danger py-2">{{ error() }}</div>
        }

        <form [formGroup]="form" (ngSubmit)="login()">
          <div class="mb-3">
            <label class="form-label">Email Address</label>
            <input type="email" class="form-control" formControlName="email"
                   autocomplete="email" placeholder="you@example.com" />
          </div>
          <div class="mb-3">
            <label class="form-label">Password</label>
            <input type="password" class="form-control" formControlName="password"
                   autocomplete="current-password" placeholder="••••••••" />
          </div>

          <button type="submit" class="btn btn-primary w-100"
                  [disabled]="form.invalid || loading()">
            @if (loading()) {
              <span class="spinner-border spinner-border-sm me-2"></span>
            }
            Sign In
          </button>
        </form>

        <p class="text-center mt-3 mb-0">
          Don't have an account?
          <a routerLink="/auth/register">Register here</a>
        </p>
      </div>
    </div>
  `
})
export class LoginComponent {
  private fb = inject(FormBuilder);
  private authService = inject(AuthService);
  private router = inject(Router);

  loading = signal(false);
  error = signal('');

  form = this.fb.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(6)]]
  });

  login(): void {
    if (this.form.invalid) return;
    this.loading.set(true);
    this.error.set('');

    this.authService.login(this.form.value as { email: string; password: string }).subscribe({
      next: () => this.router.navigate(['/']),
      error: () => {
        this.error.set('Invalid email or password.');
        this.loading.set(false);
      }
    });
  }
}
