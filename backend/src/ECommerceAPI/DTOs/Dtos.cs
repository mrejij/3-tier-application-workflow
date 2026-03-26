namespace ECommerceAPI.DTOs;

// ── Product DTOs ──────────────────────────────────────────────────────────────
public record ProductDto(
    int Id,
    string Name,
    string Description,
    decimal Price,
    decimal? DiscountPrice,
    string ImageUrl,
    int CategoryId,
    string CategoryName,
    string Sku,
    int StockQuantity,
    decimal Rating,
    int ReviewCount,
    bool IsActive,
    DateTime CreatedAt
);

public record CreateProductDto(
    string Name,
    string Description,
    decimal Price,
    decimal? DiscountPrice,
    string ImageUrl,
    int CategoryId,
    string Sku,
    int StockQuantity,
    bool IsFeatured = false
);

public record UpdateProductDto(
    string? Name,
    string? Description,
    decimal? Price,
    decimal? DiscountPrice,
    string? ImageUrl,
    int? StockQuantity,
    bool? IsActive,
    bool? IsFeatured
);

public record CategoryDto(int Id, string Name, string Description, string ImageUrl);

public class ProductFilterDto
{
    public int? CategoryId { get; set; }
    public decimal? MinPrice { get; set; }
    public decimal? MaxPrice { get; set; }
    public string? SearchTerm { get; set; }
    public int PageNumber { get; set; } = 1;
    public int PageSize { get; set; } = 12;
    public string SortBy { get; set; } = "createdAt";
    public string SortDirection { get; set; } = "desc";
}

// ── Auth DTOs ─────────────────────────────────────────────────────────────────
public record LoginDto(string Email, string Password);

public record RegisterDto(
    string Email,
    string Password,
    string ConfirmPassword,
    string FirstName,
    string LastName
);

public record AuthResponseDto(
    string Token,
    string RefreshToken,
    DateTime ExpiresAt,
    UserDto User
);

public record RefreshTokenDto(string RefreshToken);

// ── User DTOs ─────────────────────────────────────────────────────────────────
public record UserDto(
    int Id,
    string Email,
    string FirstName,
    string LastName,
    string Role,
    DateTime CreatedAt
);

// ── Order DTOs ────────────────────────────────────────────────────────────────
public record CreateOrderDto(
    ShippingAddressDto ShippingAddress,
    string PaymentMethod,
    string? CouponCode
);

public record ShippingAddressDto(
    string FullName,
    string AddressLine1,
    string? AddressLine2,
    string City,
    string State,
    string PostalCode,
    string Country,
    string Phone
);

public record OrderDto(
    int Id,
    string OrderNumber,
    string Status,
    IList<OrderItemDto> Items,
    ShippingAddressDto ShippingAddress,
    decimal Subtotal,
    decimal ShippingCost,
    decimal Tax,
    decimal Total,
    string PaymentMethod,
    DateTime CreatedAt,
    DateTime UpdatedAt
);

public record OrderItemDto(
    int ProductId,
    string ProductName,
    string Sku,
    decimal UnitPrice,
    int Quantity,
    decimal Subtotal
);

// ── Paginated Result ──────────────────────────────────────────────────────────
public record PagedResultDto<T>(
    IList<T> Items,
    int TotalCount,
    int PageNumber,
    int PageSize,
    int TotalPages,
    bool HasPreviousPage,
    bool HasNextPage
);

// ── Error Response ────────────────────────────────────────────────────────────
public record ErrorResponseDto(string Message, string? Details = null, int StatusCode = 400);
