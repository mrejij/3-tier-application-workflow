-- ============================================================
-- Migration 002 — Seed Data (Categories + Sample Products)
-- ============================================================

SET IDENTITY_INSERT Categories ON;
INSERT INTO Categories (Id, Name, Description, ImageUrl, IsActive) VALUES
(1, 'Electronics',    'Phones, laptops, accessories & more',      'https://placehold.co/200x200?text=Electronics',    1),
(2, 'Clothing',       'Men, Women & Kids fashion',                'https://placehold.co/200x200?text=Clothing',       1),
(3, 'Home & Kitchen', 'Furniture, appliances & home essentials',  'https://placehold.co/200x200?text=Home',           1),
(4, 'Books',          'Best sellers, textbooks & e-books',        'https://placehold.co/200x200?text=Books',          1),
(5, 'Sports',         'Fitness equipment & outdoor gear',         'https://placehold.co/200x200?text=Sports',         1),
(6, 'Beauty',         'Skincare, makeup & personal care',         'https://placehold.co/200x200?text=Beauty',         1);
SET IDENTITY_INSERT Categories OFF;
GO

-- ── Seed Products ─────────────────────────────────────────────
INSERT INTO Products
    (Name, Description, Price, DiscountPrice, ImageUrl, CategoryId, Sku, StockQuantity, Rating, ReviewCount, IsActive, IsFeatured)
VALUES
-- Electronics
('Wireless Noise-Cancelling Headphones',
 'Premium over-ear headphones with 30-hour battery and active noise cancellation.',
 249.99, 199.99, 'https://placehold.co/400x400?text=Headphones', 1, 'ELEC-HDP-001', 150, 4.70, 892, 1, 1),

('Mechanical Gaming Keyboard',
 'RGB backlit mechanical keyboard with Cherry MX switches and programmable macros.',
 129.99, NULL, 'https://placehold.co/400x400?text=Keyboard', 1, 'ELEC-KBD-002', 200, 4.50, 453, 1, 1),

('4K Ultra HD Monitor 27"',
 'IPS display with HDR400, 144Hz refresh rate and USB-C connectivity.',
 599.99, 499.99, 'https://placehold.co/400x400?text=Monitor', 1, 'ELEC-MON-003', 75, 4.80, 317, 1, 1),

('True Wireless Earbuds',
 'IPX5 water resistant earbuds with 24-hour case battery and ambient mode.',
 89.99, 69.99, 'https://placehold.co/400x400?text=Earbuds', 1, 'ELEC-EAR-004', 300, 4.30, 1245, 1, 0),

-- Clothing
('Classic White Oxford Shirt',
 '100% cotton slim-fit Oxford shirt, machine washable.',
 49.99, NULL, 'https://placehold.co/400x400?text=Shirt', 2, 'CLO-SHT-001', 500, 4.20, 234, 1, 0),

('Premium Running Sneakers',
 'Lightweight breathable mesh upper with responsive foam cushioning.',
 119.99, 89.99, 'https://placehold.co/400x400?text=Sneakers', 2, 'CLO-SNK-002', 250, 4.60, 678, 1, 1),

-- Home & Kitchen
('12-Cup Programmable Coffee Maker',
 'Brew hot or iced coffee with glass carafe, 24-hour programmable timer.',
 79.99, 59.99, 'https://placehold.co/400x400?text=Coffee+Maker', 3, 'HOM-COF-001', 180, 4.40, 892, 1, 1),

('Ergonomic Office Chair',
 'Adjustable lumbar support, mesh back, armrests and 5-year warranty.',
 349.99, 299.99, 'https://placehold.co/400x400?text=Chair', 3, 'HOM-CHA-002', 90, 4.70, 456, 1, 0),

-- Books
('Clean Code: A Handbook of Agile Software',
 'Timeless guide to writing clean, maintainable code by Robert C. Martin.',
 34.99, 24.99, 'https://placehold.co/400x400?text=Clean+Code', 4, 'BOK-CC-001', 999, 4.90, 3421, 1, 1),

('The DevOps Handbook',
 'How to create world-class agility, reliability and security in technology organisations.',
 39.99, 29.99, 'https://placehold.co/400x400?text=DevOps+Handbook', 4, 'BOK-DEV-002', 999, 4.80, 1892, 1, 1),

-- Sports
('Adjustable Dumbbell Set 5-52 lbs',
 'Space-saving adjustable dumbbells replacing 15 sets of weights.',
 299.99, 249.99, 'https://placehold.co/400x400?text=Dumbbells', 5, 'SPO-DUM-001', 60, 4.60, 567, 1, 1),

-- Beauty
('Vitamin C Brightening Serum',
 '20% Vitamin C with hyaluronic acid and niacinamide for glowing skin.',
 44.99, NULL, 'https://placehold.co/400x400?text=Serum', 6, 'BEA-SER-001', 400, 4.50, 1023, 1, 0);
GO

-- ── Seed Admin User ───────────────────────────────────────────
-- Password: Admin@123  (BCrypt hash, work factor 12)
-- IMPORTANT: Change this password immediately after first login.
INSERT INTO Users (Email, PasswordHash, FirstName, LastName, Role, IsActive)
VALUES (
    'admin@shopmart.com',
    '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj0A81NUQfTu',
    'Shop',
    'Admin',
    'Admin',
    1
);
GO

PRINT 'Migration 002 — Seed Data applied successfully.';
GO
