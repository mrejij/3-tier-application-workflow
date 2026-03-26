using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ECommerceAPI.Models;

public enum OrderStatus
{
    Pending,
    Processing,
    Shipped,
    Delivered,
    Cancelled
}

public class Order
{
    [Key]
    public int Id { get; set; }

    [Required, MaxLength(50)]
    public string OrderNumber { get; set; } = string.Empty;

    public int UserId { get; set; }

    [ForeignKey(nameof(UserId))]
    public User User { get; set; } = null!;

    public OrderStatus Status { get; set; } = OrderStatus.Pending;

    public ICollection<OrderItem> Items { get; set; } = [];

    // Shipping Address (denormalized for immutability)
    [Required, MaxLength(200)]
    public string ShippingFullName { get; set; } = string.Empty;

    [Required, MaxLength(300)]
    public string ShippingAddressLine1 { get; set; } = string.Empty;

    [MaxLength(300)]
    public string? ShippingAddressLine2 { get; set; }

    [Required, MaxLength(100)]
    public string ShippingCity { get; set; } = string.Empty;

    [Required, MaxLength(100)]
    public string ShippingState { get; set; } = string.Empty;

    [Required, MaxLength(20)]
    public string ShippingPostalCode { get; set; } = string.Empty;

    [Required, MaxLength(100)]
    public string ShippingCountry { get; set; } = string.Empty;

    [Required, MaxLength(30)]
    public string ShippingPhone { get; set; } = string.Empty;

    [Column(TypeName = "decimal(18,2)")]
    public decimal Subtotal { get; set; }

    [Column(TypeName = "decimal(18,2)")]
    public decimal ShippingCost { get; set; }

    [Column(TypeName = "decimal(18,2)")]
    public decimal Tax { get; set; }

    [Column(TypeName = "decimal(18,2)")]
    public decimal Total { get; set; }

    [MaxLength(50)]
    public string PaymentMethod { get; set; } = string.Empty;

    [MaxLength(100)]
    public string? PaymentTransactionId { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

public class OrderItem
{
    [Key]
    public int Id { get; set; }

    public int OrderId { get; set; }

    [ForeignKey(nameof(OrderId))]
    public Order Order { get; set; } = null!;

    public int ProductId { get; set; }

    [ForeignKey(nameof(ProductId))]
    public Product Product { get; set; } = null!;

    [Required, MaxLength(200)]
    public string ProductName { get; set; } = string.Empty;

    [Required, MaxLength(100)]
    public string Sku { get; set; } = string.Empty;

    [Column(TypeName = "decimal(18,2)")]
    public decimal UnitPrice { get; set; }

    public int Quantity { get; set; }

    [Column(TypeName = "decimal(18,2)")]
    public decimal Subtotal { get; set; }
}
