import { Component, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators, AbstractControl, ValidationErrors } from '@angular/forms';
import { AuthService } from '../../../services/auth.service';
import { RegisterRequest } from '../../../models/user.model';

function passwordMatchValidator(control: AbstractControl): ValidationErrors | null {
  const password = control.get('password')?.value;
  const confirm = control.get('confirmPassword')?.value;
  return password === confirm ? null : { passwordMismatch: true };
}

@Component({
  selector: 'app-register',
  standalone: true,
  imports: [RouterLink, CommonModule, ReactiveFormsModule],
  template: `
    <div class="d-flex justify-content-center align-items-center" style="min-height:80vh;">
      <div class="card p-4 shadow" style="width:100%;max-width:480px;">
        <h3 class="fw-bold text-center mb-4">Create Account</h3>

        @if (error()) {
          <div class="alert alert-danger py-2">{{ error() }}</div>
        }

        <form [formGroup]="form" (ngSubmit)="register()">
          <div class="row g-3">
            <div class="col-md-6">
              <label class="form-label">First Name</label>
              <input class="form-control" formControlName="firstName" />
            </div>
            <div class="col-md-6">
              <label class="form-label">Last Name</label>
              <input class="form-control" formControlName="lastName" />
            </div>
            <div class="col-12">
              <label class="form-label">Email Address</label>
              <input type="email" class="form-control" formControlName="email"
                     autocomplete="email" />
            </div>
            <div class="col-12">
              <label class="form-label">Password</label>
              <input type="password" class="form-control" formControlName="password"
                     autocomplete="new-password" />
              <small class="text-muted">Minimum 8 characters with numbers and symbols</small>
            </div>
            <div class="col-12">
              <label class="form-label">Confirm Password</label>
              <input type="password" class="form-control" formControlName="confirmPassword"
                     autocomplete="new-password" />
              @if (form.hasError('passwordMismatch') && form.get('confirmPassword')?.touched) {
                <div class="invalid-feedback d-block">Passwords do not match</div>
              }
            </div>
          </div>

          <button type="submit" class="btn btn-primary w-100 mt-4"
                  [disabled]="form.invalid || loading()">
            @if (loading()) {
              <span class="spinner-border spinner-border-sm me-2"></span>
            }
            Create Account
          </button>
        </form>

        <p class="text-center mt-3 mb-0">
          Already have an account? <a routerLink="/auth/login">Sign in</a>
        </p>
      </div>
    </div>
  `
})
export class RegisterComponent {
  private fb = inject(FormBuilder);
  private authService = inject(AuthService);
  private router = inject(Router);

  loading = signal(false);
  error = signal('');

  form = this.fb.group({
    firstName: ['', Validators.required],
    lastName: ['', Validators.required],
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(8),
      Validators.pattern(/^(?=.*[0-9])(?=.*[!@#$%^&*]).*$/)]],
    confirmPassword: ['', Validators.required]
  }, { validators: passwordMatchValidator });

  register(): void {
    if (this.form.invalid) return;
    this.loading.set(true);
    this.error.set('');

    this.authService.register(this.form.value as RegisterRequest).subscribe({
      next: () => this.router.navigate(['/']),
      error: (err) => {
        this.error.set(err?.error?.message ?? 'Registration failed. Please try again.');
        this.loading.set(false);
      }
    });
  }
}
