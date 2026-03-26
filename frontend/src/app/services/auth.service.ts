import { Injectable, signal, computed } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, tap, catchError, throwError } from 'rxjs';
import { jwtDecode } from 'jwt-decode';
import { environment } from '../../environments/environment';
import { AuthResponse, LoginRequest, RegisterRequest, User } from '../models/user.model';

interface JwtPayload {
  sub: string;
  email: string;
  role: string;
  exp: number;
}

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly TOKEN_KEY = 'auth_token';
  private readonly REFRESH_KEY = 'refresh_token';

  private _currentUser = signal<User | null>(null);
  readonly currentUser = this._currentUser.asReadonly();
  readonly isLoggedIn = computed(() => this._currentUser() !== null);
  readonly isAdmin = computed(() => this._currentUser()?.role === 'Admin');

  constructor(private http: HttpClient, private router: Router) {
    this.restoreSession();
  }

  login(request: LoginRequest): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${environment.apiUrl}/auth/login`, request).pipe(
      tap(resp => this.persistSession(resp)),
      catchError(err => throwError(() => err))
    );
  }

  register(request: RegisterRequest): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${environment.apiUrl}/auth/register`, request).pipe(
      tap(resp => this.persistSession(resp)),
      catchError(err => throwError(() => err))
    );
  }

  refreshToken(): Observable<AuthResponse> {
    const refreshToken = this.getRefreshToken();
    return this.http.post<AuthResponse>(`${environment.apiUrl}/auth/refresh`, { refreshToken }).pipe(
      tap(resp => this.persistSession(resp)),
      catchError(err => {
        this.logout();
        return throwError(() => err);
      })
    );
  }

  logout(): void {
    localStorage.removeItem(this.TOKEN_KEY);
    localStorage.removeItem(this.REFRESH_KEY);
    this._currentUser.set(null);
    this.router.navigate(['/auth/login']);
  }

  getToken(): string | null {
    return localStorage.getItem(this.TOKEN_KEY);
  }

  getRefreshToken(): string | null {
    return localStorage.getItem(this.REFRESH_KEY);
  }

  isTokenExpired(): boolean {
    const token = this.getToken();
    if (!token) return true;
    try {
      const decoded = jwtDecode<JwtPayload>(token);
      return decoded.exp * 1000 < Date.now();
    } catch {
      return true;
    }
  }

  private persistSession(resp: AuthResponse): void {
    localStorage.setItem(this.TOKEN_KEY, resp.token);
    localStorage.setItem(this.REFRESH_KEY, resp.refreshToken);
    this._currentUser.set(resp.user);
  }

  private restoreSession(): void {
    const token = this.getToken();
    if (token && !this.isTokenExpired()) {
      try {
        const decoded = jwtDecode<JwtPayload>(token);
        // Minimal restoration — a full profile call could be made here
        this._currentUser.set({
          id: parseInt(decoded.sub),
          email: decoded.email,
          firstName: '',
          lastName: '',
          role: decoded.role as 'Customer' | 'Admin',
          createdAt: ''
        });
      } catch {
        this.logout();
      }
    }
  }
}
