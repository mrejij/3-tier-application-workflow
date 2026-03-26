using ECommerceAPI.Data;
using ECommerceAPI.DTOs;
using ECommerceAPI.Models;
using Microsoft.EntityFrameworkCore;

namespace ECommerceAPI.Services;

// Cart is session-based and managed client-side (Angular CartService).
// This server-side service handles cart→order conversion validation.
public interface ICartService
{
    Task<bool> ValidateCartItemsAsync(IEnumerable<int> productIds);
    Task<Dictionary<int, Product>> GetProductsForCartAsync(IEnumerable<int> productIds);
}

public class CartService : ICartService
{
    private readonly AppDbContext _db;

    public CartService(AppDbContext db) => _db = db;

    public async Task<bool> ValidateCartItemsAsync(IEnumerable<int> productIds)
    {
        var ids = productIds.Distinct().ToList();
        var activeCount = await _db.Products
            .CountAsync(p => ids.Contains(p.Id) && p.IsActive && p.StockQuantity > 0);
        return activeCount == ids.Count;
    }

    public async Task<Dictionary<int, Product>> GetProductsForCartAsync(IEnumerable<int> productIds)
    {
        var ids = productIds.Distinct().ToList();
        return await _db.Products
            .Where(p => ids.Contains(p.Id) && p.IsActive)
            .ToDictionaryAsync(p => p.Id);
    }
}
