using AutoMapper;
using ECommerceAPI.Data;
using ECommerceAPI.DTOs;
using ECommerceAPI.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace ECommerceAPI.Services;

public interface IOrderService
{
    Task<OrderDto> CreateOrderAsync(int userId, CreateOrderDto dto);
    Task<PagedResultDto<OrderDto>> GetUserOrdersAsync(int userId, int pageNumber, int pageSize);
    Task<OrderDto> GetOrderByIdAsync(int id, int userId, bool isAdmin = false);
    Task<OrderDto> GetOrderByNumberAsync(string orderNumber);
    Task<OrderDto> UpdateStatusAsync(int id, string status);
    Task CancelOrderAsync(int id, int userId);
}

public class OrderService : IOrderService
{
    private readonly AppDbContext _db;
    private readonly IMapper _mapper;

    public OrderService(AppDbContext db, IMapper mapper)
    {
        _db = db;
        _mapper = mapper;
    }

    public async Task<OrderDto> CreateOrderAsync(int userId, CreateOrderDto dto)
    {
        // Load cart items — in this implementation cart is client-side,
        // so we trust the server-side product prices (never trust client prices).
        // A real implementation would have a server-side cart table.
        // For now, this creates the order structure; cart items would be passed validated.

        var order = new Order
        {
            OrderNumber = GenerateOrderNumber(),
            UserId = userId,
            Status = OrderStatus.Pending,
            PaymentMethod = dto.PaymentMethod,
            ShippingFullName = dto.ShippingAddress.FullName,
            ShippingAddressLine1 = dto.ShippingAddress.AddressLine1,
            ShippingAddressLine2 = dto.ShippingAddress.AddressLine2,
            ShippingCity = dto.ShippingAddress.City,
            ShippingState = dto.ShippingAddress.State,
            ShippingPostalCode = dto.ShippingAddress.PostalCode,
            ShippingCountry = dto.ShippingAddress.Country,
            ShippingPhone = dto.ShippingAddress.Phone,
            ShippingCost = 0,
            Tax = 0,
            Subtotal = 0,
            Total = 0
        };

        _db.Orders.Add(order);
        await _db.SaveChangesAsync();

        await _db.Entry(order).Collection(o => o.Items).LoadAsync();
        return _mapper.Map<OrderDto>(order);
    }

    public async Task<PagedResultDto<OrderDto>> GetUserOrdersAsync(int userId, int pageNumber, int pageSize)
    {
        pageNumber = Math.Max(1, pageNumber);
        pageSize = Math.Min(pageSize, 50);

        var query = _db.Orders
            .Include(o => o.Items)
            .Where(o => o.UserId == userId)
            .OrderByDescending(o => o.CreatedAt);

        var total = await query.CountAsync();
        var totalPages = (int)Math.Ceiling((double)total / pageSize);
        var items = await query
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        return new PagedResultDto<OrderDto>(
            _mapper.Map<IList<OrderDto>>(items),
            total, pageNumber, pageSize, totalPages,
            pageNumber > 1, pageNumber < totalPages
        );
    }

    public async Task<OrderDto> GetOrderByIdAsync(int id, int userId, bool isAdmin = false)
    {
        var query = _db.Orders.Include(o => o.Items).AsQueryable();
        var order = isAdmin
            ? await query.FirstOrDefaultAsync(o => o.Id == id)
            : await query.FirstOrDefaultAsync(o => o.Id == id && o.UserId == userId);

        return _mapper.Map<OrderDto>(order ?? throw new KeyNotFoundException($"Order {id} not found."));
    }

    public async Task<OrderDto> GetOrderByNumberAsync(string orderNumber)
    {
        var order = await _db.Orders
            .Include(o => o.Items)
            .FirstOrDefaultAsync(o => o.OrderNumber == orderNumber)
            ?? throw new KeyNotFoundException($"Order {orderNumber} not found.");
        return _mapper.Map<OrderDto>(order);
    }

    public async Task<OrderDto> UpdateStatusAsync(int id, string status)
    {
        if (!Enum.TryParse<OrderStatus>(status, ignoreCase: true, out var newStatus))
            throw new ArgumentException($"Invalid status '{status}'.");

        var order = await _db.Orders.Include(o => o.Items).FirstOrDefaultAsync(o => o.Id == id)
            ?? throw new KeyNotFoundException($"Order {id} not found.");

        order.Status = newStatus;
        await _db.SaveChangesAsync();
        return _mapper.Map<OrderDto>(order);
    }

    public async Task CancelOrderAsync(int id, int userId)
    {
        var order = await _db.Orders.FirstOrDefaultAsync(o => o.Id == id && o.UserId == userId)
            ?? throw new KeyNotFoundException($"Order {id} not found.");

        if (order.Status is not (OrderStatus.Pending or OrderStatus.Processing))
            throw new InvalidOperationException("Only Pending or Processing orders can be cancelled.");

        order.Status = OrderStatus.Cancelled;
        await _db.SaveChangesAsync();
    }

    private static string GenerateOrderNumber()
        => $"ORD-{DateTime.UtcNow:yyyyMMdd}-{Guid.NewGuid().ToString("N")[..8].ToUpper()}";
}
