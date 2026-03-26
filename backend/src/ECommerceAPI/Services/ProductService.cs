using AutoMapper;
using ECommerceAPI.Data;
using ECommerceAPI.DTOs;
using ECommerceAPI.Models;
using Microsoft.EntityFrameworkCore;

namespace ECommerceAPI.Services;

public interface IProductService
{
    Task<PagedResultDto<ProductDto>> GetProductsAsync(ProductFilterDto filter);
    Task<ProductDto> GetByIdAsync(int id);
    Task<IList<ProductDto>> GetFeaturedAsync();
    Task<IList<CategoryDto>> GetCategoriesAsync();
    Task<ProductDto> CreateAsync(CreateProductDto dto);
    Task<ProductDto> UpdateAsync(int id, UpdateProductDto dto);
    Task DeleteAsync(int id);
}

public class ProductService : IProductService
{
    private readonly AppDbContext _db;
    private readonly IMapper _mapper;
    private readonly IConfiguration _config;

    public ProductService(AppDbContext db, IMapper mapper, IConfiguration config)
    {
        _db = db;
        _mapper = mapper;
        _config = config;
    }

    public async Task<PagedResultDto<ProductDto>> GetProductsAsync(ProductFilterDto filter)
    {
        var maxPageSize = int.Parse(_config["Pagination:MaxPageSize"] ?? "50");
        filter.PageSize = Math.Min(filter.PageSize, maxPageSize);
        filter.PageNumber = Math.Max(1, filter.PageNumber);

        var query = _db.Products
            .Include(p => p.Category)
            .Where(p => p.IsActive)
            .AsQueryable();

        if (filter.CategoryId.HasValue)
            query = query.Where(p => p.CategoryId == filter.CategoryId.Value);

        if (filter.MinPrice.HasValue)
            query = query.Where(p => (p.DiscountPrice ?? p.Price) >= filter.MinPrice.Value);

        if (filter.MaxPrice.HasValue)
            query = query.Where(p => (p.DiscountPrice ?? p.Price) <= filter.MaxPrice.Value);

        if (!string.IsNullOrWhiteSpace(filter.SearchTerm))
        {
            var term = filter.SearchTerm.Trim().ToLower();
            query = query.Where(p => p.Name.ToLower().Contains(term) ||
                                     p.Description.ToLower().Contains(term) ||
                                     p.Sku.ToLower().Contains(term));
        }

        query = (filter.SortBy?.ToLower(), filter.SortDirection?.ToLower()) switch
        {
            ("price", "asc") => query.OrderBy(p => p.DiscountPrice ?? p.Price),
            ("price", _) => query.OrderByDescending(p => p.DiscountPrice ?? p.Price),
            ("rating", _) => query.OrderByDescending(p => p.Rating),
            ("name", "desc") => query.OrderByDescending(p => p.Name),
            ("name", _) => query.OrderBy(p => p.Name),
            _ => query.OrderByDescending(p => p.CreatedAt)
        };

        var totalCount = await query.CountAsync();
        var totalPages = (int)Math.Ceiling((double)totalCount / filter.PageSize);

        var items = await query
            .Skip((filter.PageNumber - 1) * filter.PageSize)
            .Take(filter.PageSize)
            .ToListAsync();

        return new PagedResultDto<ProductDto>(
            _mapper.Map<IList<ProductDto>>(items),
            totalCount,
            filter.PageNumber,
            filter.PageSize,
            totalPages,
            filter.PageNumber > 1,
            filter.PageNumber < totalPages
        );
    }

    public async Task<ProductDto> GetByIdAsync(int id)
    {
        var product = await _db.Products
            .Include(p => p.Category)
            .FirstOrDefaultAsync(p => p.Id == id && p.IsActive)
            ?? throw new KeyNotFoundException($"Product {id} not found.");

        return _mapper.Map<ProductDto>(product);
    }

    public async Task<IList<ProductDto>> GetFeaturedAsync()
    {
        var products = await _db.Products
            .Include(p => p.Category)
            .Where(p => p.IsActive && p.IsFeatured)
            .OrderByDescending(p => p.CreatedAt)
            .Take(12)
            .ToListAsync();

        return _mapper.Map<IList<ProductDto>>(products);
    }

    public async Task<IList<CategoryDto>> GetCategoriesAsync()
    {
        var categories = await _db.Categories
            .Where(c => c.IsActive)
            .OrderBy(c => c.Name)
            .ToListAsync();

        return _mapper.Map<IList<CategoryDto>>(categories);
    }

    public async Task<ProductDto> CreateAsync(CreateProductDto dto)
    {
        if (await _db.Products.AnyAsync(p => p.Sku == dto.Sku))
            throw new InvalidOperationException($"SKU '{dto.Sku}' is already in use.");

        var product = new Product
        {
            Name = dto.Name,
            Description = dto.Description,
            Price = dto.Price,
            DiscountPrice = dto.DiscountPrice,
            ImageUrl = dto.ImageUrl,
            CategoryId = dto.CategoryId,
            Sku = dto.Sku,
            StockQuantity = dto.StockQuantity,
            IsFeatured = dto.IsFeatured
        };

        _db.Products.Add(product);
        await _db.SaveChangesAsync();
        await _db.Entry(product).Reference(p => p.Category).LoadAsync();

        return _mapper.Map<ProductDto>(product);
    }

    public async Task<ProductDto> UpdateAsync(int id, UpdateProductDto dto)
    {
        var product = await _db.Products
            .Include(p => p.Category)
            .FirstOrDefaultAsync(p => p.Id == id)
            ?? throw new KeyNotFoundException($"Product {id} not found.");

        if (dto.Name != null) product.Name = dto.Name;
        if (dto.Description != null) product.Description = dto.Description;
        if (dto.Price.HasValue) product.Price = dto.Price.Value;
        if (dto.DiscountPrice.HasValue) product.DiscountPrice = dto.DiscountPrice;
        if (dto.ImageUrl != null) product.ImageUrl = dto.ImageUrl;
        if (dto.StockQuantity.HasValue) product.StockQuantity = dto.StockQuantity.Value;
        if (dto.IsActive.HasValue) product.IsActive = dto.IsActive.Value;
        if (dto.IsFeatured.HasValue) product.IsFeatured = dto.IsFeatured.Value;

        await _db.SaveChangesAsync();
        return _mapper.Map<ProductDto>(product);
    }

    public async Task DeleteAsync(int id)
    {
        var product = await _db.Products.FindAsync(id)
            ?? throw new KeyNotFoundException($"Product {id} not found.");

        product.IsActive = false; // Soft delete
        await _db.SaveChangesAsync();
    }
}
