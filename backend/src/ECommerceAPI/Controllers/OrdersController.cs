using ECommerceAPI.DTOs;
using ECommerceAPI.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace ECommerceAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class OrdersController : ControllerBase
{
    private readonly IOrderService _orderService;

    public OrdersController(IOrderService orderService) => _orderService = orderService;

    [HttpPost]
    [ProducesResponseType(typeof(OrderDto), StatusCodes.Status201Created)]
    public async Task<IActionResult> CreateOrder([FromBody] CreateOrderDto dto)
    {
        var userId = GetUserId();
        var order = await _orderService.CreateOrderAsync(userId, dto);
        return CreatedAtAction(nameof(GetById), new { id = order.Id }, order);
    }

    [HttpGet("my-orders")]
    [ProducesResponseType(typeof(PagedResultDto<OrderDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetMyOrders(
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 10)
    {
        var userId = GetUserId();
        var result = await _orderService.GetUserOrdersAsync(userId, pageNumber, pageSize);
        return Ok(result);
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(OrderDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetById(int id)
    {
        var userId = GetUserId();
        var isAdmin = User.IsInRole("Admin");
        var order = await _orderService.GetOrderByIdAsync(id, userId, isAdmin);
        return Ok(order);
    }

    [HttpGet("track/{orderNumber}")]
    [ProducesResponseType(typeof(OrderDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> Track(string orderNumber)
    {
        var order = await _orderService.GetOrderByNumberAsync(orderNumber);
        return Ok(order);
    }

    [HttpPatch("{id:int}/cancel")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Cancel(int id)
    {
        var userId = GetUserId();
        await _orderService.CancelOrderAsync(id, userId);
        return NoContent();
    }

    [HttpPatch("{id:int}/status")]
    [Authorize(Policy = "AdminOnly")]
    [ProducesResponseType(typeof(OrderDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> UpdateStatus(int id, [FromBody] string status)
    {
        var order = await _orderService.UpdateStatusAsync(id, status);
        return Ok(order);
    }

    private int GetUserId() =>
        int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? throw new UnauthorizedAccessException("User ID claim missing."));
}
