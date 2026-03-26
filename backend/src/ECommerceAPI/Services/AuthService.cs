using ECommerceAPI.Data;
using ECommerceAPI.DTOs;
using ECommerceAPI.Models;
using Microsoft.EntityFrameworkCore;

namespace ECommerceAPI.Services;

public interface IAuthService
{
    Task<AuthResponseDto> RegisterAsync(RegisterDto dto);
    Task<AuthResponseDto> LoginAsync(LoginDto dto);
    Task<AuthResponseDto> RefreshTokenAsync(string refreshToken);
    Task RevokeTokenAsync(int userId);
}

public class AuthService : IAuthService
{
    private readonly AppDbContext _db;
    private readonly ITokenService _tokenService;
    private readonly IConfiguration _config;

    public AuthService(AppDbContext db, ITokenService tokenService, IConfiguration config)
    {
        _db = db;
        _tokenService = tokenService;
        _config = config;
    }

    public async Task<AuthResponseDto> RegisterAsync(RegisterDto dto)
    {
        if (await _db.Users.AnyAsync(u => u.Email == dto.Email.ToLowerInvariant()))
            throw new InvalidOperationException("An account with this email already exists.");

        var user = new User
        {
            Email = dto.Email.ToLowerInvariant().Trim(),
            FirstName = dto.FirstName.Trim(),
            LastName = dto.LastName.Trim(),
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.Password, workFactor: 12),
            Role = UserRole.Customer
        };

        var refreshToken = _tokenService.GenerateRefreshToken();
        user.RefreshToken = refreshToken;
        user.RefreshTokenExpiry = DateTime.UtcNow.AddDays(
            int.Parse(_config["Jwt:RefreshTokenExpiryDays"] ?? "7"));

        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        var accessToken = _tokenService.GenerateAccessToken(user);
        return BuildAuthResponse(user, accessToken, refreshToken);
    }

    public async Task<AuthResponseDto> LoginAsync(LoginDto dto)
    {
        var user = await _db.Users
            .FirstOrDefaultAsync(u => u.Email == dto.Email.ToLowerInvariant() && u.IsActive)
            ?? throw new UnauthorizedAccessException("Invalid email or password.");

        if (!BCrypt.Net.BCrypt.Verify(dto.Password, user.PasswordHash))
            throw new UnauthorizedAccessException("Invalid email or password.");

        var accessToken = _tokenService.GenerateAccessToken(user);
        var refreshToken = _tokenService.GenerateRefreshToken();

        user.RefreshToken = refreshToken;
        user.RefreshTokenExpiry = DateTime.UtcNow.AddDays(
            int.Parse(_config["Jwt:RefreshTokenExpiryDays"] ?? "7"));

        await _db.SaveChangesAsync();

        return BuildAuthResponse(user, accessToken, refreshToken);
    }

    public async Task<AuthResponseDto> RefreshTokenAsync(string refreshToken)
    {
        var user = await _db.Users
            .FirstOrDefaultAsync(u => u.RefreshToken == refreshToken &&
                                      u.RefreshTokenExpiry > DateTime.UtcNow &&
                                      u.IsActive)
            ?? throw new UnauthorizedAccessException("Invalid or expired refresh token.");

        var newAccessToken = _tokenService.GenerateAccessToken(user);
        var newRefreshToken = _tokenService.GenerateRefreshToken();

        user.RefreshToken = newRefreshToken;
        user.RefreshTokenExpiry = DateTime.UtcNow.AddDays(
            int.Parse(_config["Jwt:RefreshTokenExpiryDays"] ?? "7"));

        await _db.SaveChangesAsync();

        return BuildAuthResponse(user, newAccessToken, newRefreshToken);
    }

    public async Task RevokeTokenAsync(int userId)
    {
        var user = await _db.Users.FindAsync(userId)
            ?? throw new KeyNotFoundException("User not found.");
        user.RefreshToken = null;
        user.RefreshTokenExpiry = null;
        await _db.SaveChangesAsync();
    }

    private static AuthResponseDto BuildAuthResponse(User user, string accessToken, string refreshToken)
    {
        var userDto = new UserDto(user.Id, user.Email, user.FirstName, user.LastName,
            user.Role.ToString(), user.CreatedAt);
        var expiresAt = DateTime.UtcNow.AddHours(1);
        return new AuthResponseDto(accessToken, refreshToken, expiresAt, userDto);
    }
}
