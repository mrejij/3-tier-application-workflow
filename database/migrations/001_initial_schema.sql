-- ============================================================
-- Migration 001 — Initial Schema
-- Azure SQL Database (compatibility level 150)
-- ============================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ── Categories ────────────────────────────────────────────────
CREATE TABLE Categories (
    Id          INT IDENTITY(1,1) NOT NULL,
    Name        NVARCHAR(100)     NOT NULL,
    Description NVARCHAR(500)     NOT NULL DEFAULT '',
    ImageUrl    NVARCHAR(500)     NOT NULL DEFAULT '',
    IsActive    BIT               NOT NULL DEFAULT 1,
    CONSTRAINT PK_Categories PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT UQ_Categories_Name UNIQUE (Name)
);
GO

-- ── Products ──────────────────────────────────────────────────
CREATE TABLE Products (
    Id            INT IDENTITY(1,1) NOT NULL,
    Name          NVARCHAR(200)     NOT NULL,
    Description   NVARCHAR(2000)    NOT NULL DEFAULT '',
    Price         DECIMAL(18,2)     NOT NULL,
    DiscountPrice DECIMAL(18,2)     NULL,
    ImageUrl      NVARCHAR(500)     NOT NULL DEFAULT '',
    CategoryId    INT               NOT NULL,
    Sku           NVARCHAR(100)     NOT NULL,
    StockQuantity INT               NOT NULL DEFAULT 0,
    Rating        DECIMAL(3,2)      NOT NULL DEFAULT 0.00,
    ReviewCount   INT               NOT NULL DEFAULT 0,
    IsActive      BIT               NOT NULL DEFAULT 1,
    IsFeatured    BIT               NOT NULL DEFAULT 0,
    CreatedAt     DATETIME2         NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt     DATETIME2         NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Products PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT UQ_Products_Sku UNIQUE (Sku),
    CONSTRAINT FK_Products_Categories FOREIGN KEY (CategoryId)
        REFERENCES Categories(Id) ON DELETE NO ACTION,
    CONSTRAINT CK_Products_Price CHECK (Price >= 0),
    CONSTRAINT CK_Products_DiscountPrice CHECK (DiscountPrice IS NULL OR DiscountPrice >= 0),
    CONSTRAINT CK_Products_StockQuantity CHECK (StockQuantity >= 0),
    CONSTRAINT CK_Products_Rating CHECK (Rating BETWEEN 0.00 AND 5.00)
);
CREATE INDEX IX_Products_CategoryId        ON Products (CategoryId);
CREATE INDEX IX_Products_IsActive_Featured ON Products (IsActive, IsFeatured);
CREATE INDEX IX_Products_CreatedAt         ON Products (CreatedAt DESC);
GO

-- ── Users ─────────────────────────────────────────────────────
CREATE TABLE Users (
    Id                  INT IDENTITY(1,1) NOT NULL,
    Email               NVARCHAR(256)     NOT NULL,
    PasswordHash        NVARCHAR(500)     NOT NULL,
    FirstName           NVARCHAR(100)     NOT NULL,
    LastName            NVARCHAR(100)     NOT NULL,
    Role                NVARCHAR(20)      NOT NULL DEFAULT 'Customer',
    IsActive            BIT               NOT NULL DEFAULT 1,
    RefreshToken        NVARCHAR(200)     NULL,
    RefreshTokenExpiry  DATETIME2         NULL,
    CreatedAt           DATETIME2         NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt           DATETIME2         NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Users PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT UQ_Users_Email UNIQUE (Email),
    CONSTRAINT CK_Users_Role CHECK (Role IN ('Customer', 'Admin'))
);
GO

-- ── Orders ────────────────────────────────────────────────────
CREATE TABLE Orders (
    Id                   INT IDENTITY(1,1) NOT NULL,
    OrderNumber          NVARCHAR(50)      NOT NULL,
    UserId               INT               NOT NULL,
    Status               NVARCHAR(20)      NOT NULL DEFAULT 'Pending',
    ShippingFullName     NVARCHAR(200)     NOT NULL,
    ShippingAddressLine1 NVARCHAR(300)     NOT NULL,
    ShippingAddressLine2 NVARCHAR(300)     NULL,
    ShippingCity         NVARCHAR(100)     NOT NULL,
    ShippingState        NVARCHAR(100)     NOT NULL,
    ShippingPostalCode   NVARCHAR(20)      NOT NULL,
    ShippingCountry      NVARCHAR(100)     NOT NULL,
    ShippingPhone        NVARCHAR(30)      NOT NULL,
    Subtotal             DECIMAL(18,2)     NOT NULL DEFAULT 0,
    ShippingCost         DECIMAL(18,2)     NOT NULL DEFAULT 0,
    Tax                  DECIMAL(18,2)     NOT NULL DEFAULT 0,
    Total                DECIMAL(18,2)     NOT NULL DEFAULT 0,
    PaymentMethod        NVARCHAR(50)      NOT NULL,
    PaymentTransactionId NVARCHAR(100)     NULL,
    CreatedAt            DATETIME2         NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt            DATETIME2         NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT UQ_Orders_OrderNumber UNIQUE (OrderNumber),
    CONSTRAINT FK_Orders_Users FOREIGN KEY (UserId)
        REFERENCES Users(Id) ON DELETE NO ACTION,
    CONSTRAINT CK_Orders_Status CHECK (
        Status IN ('Pending','Processing','Shipped','Delivered','Cancelled')
    ),
    CONSTRAINT CK_Orders_Totals CHECK (
        Subtotal >= 0 AND ShippingCost >= 0 AND Tax >= 0 AND Total >= 0
    )
);
CREATE INDEX IX_Orders_UserId_CreatedAt ON Orders (UserId, CreatedAt DESC);
CREATE INDEX IX_Orders_Status           ON Orders (Status);
GO

-- ── Order Items ───────────────────────────────────────────────
CREATE TABLE OrderItems (
    Id          INT IDENTITY(1,1) NOT NULL,
    OrderId     INT               NOT NULL,
    ProductId   INT               NOT NULL,
    ProductName NVARCHAR(200)     NOT NULL,
    Sku         NVARCHAR(100)     NOT NULL,
    UnitPrice   DECIMAL(18,2)     NOT NULL,
    Quantity    INT               NOT NULL,
    Subtotal    DECIMAL(18,2)     NOT NULL,
    CONSTRAINT PK_OrderItems PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_OrderItems_Orders FOREIGN KEY (OrderId)
        REFERENCES Orders(Id) ON DELETE CASCADE,
    CONSTRAINT FK_OrderItems_Products FOREIGN KEY (ProductId)
        REFERENCES Products(Id) ON DELETE NO ACTION,
    CONSTRAINT CK_OrderItems_Quantity CHECK (Quantity > 0),
    CONSTRAINT CK_OrderItems_UnitPrice CHECK (UnitPrice >= 0)
);
CREATE INDEX IX_OrderItems_OrderId   ON OrderItems (OrderId);
CREATE INDEX IX_OrderItems_ProductId ON OrderItems (ProductId);
GO

-- ── EF Core Migrations History Table ─────────────────────────
CREATE TABLE __EFMigrationsHistory (
    MigrationId    NVARCHAR(150) NOT NULL,
    ProductVersion NVARCHAR(32)  NOT NULL,
    CONSTRAINT PK___EFMigrationsHistory PRIMARY KEY (MigrationId)
);
GO

PRINT 'Migration 001 — Initial Schema applied successfully.';
GO
