using AutoMapper;
using ECommerceAPI.DTOs;
using ECommerceAPI.Models;

namespace ECommerceAPI.Mapping;

public class MappingProfile : Profile
{
    public MappingProfile()
    {
        CreateMap<Product, ProductDto>()
            .ForMember(d => d.CategoryName, o => o.MapFrom(s => s.Category.Name));

        CreateMap<Category, CategoryDto>();

        CreateMap<Order, OrderDto>()
            .ForMember(d => d.Status, o => o.MapFrom(s => s.Status.ToString()))
            .ForMember(d => d.ShippingAddress, o => o.MapFrom(s => new ShippingAddressDto(
                s.ShippingFullName, s.ShippingAddressLine1, s.ShippingAddressLine2,
                s.ShippingCity, s.ShippingState, s.ShippingPostalCode,
                s.ShippingCountry, s.ShippingPhone)));

        CreateMap<OrderItem, OrderItemDto>();

        CreateMap<User, UserDto>()
            .ForMember(d => d.Role, o => o.MapFrom(s => s.Role.ToString()));
    }
}
