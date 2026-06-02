// ProductInfo.swift — AI-gathered enrichment for a product link.
// Stored as a single Codable attribute on Link. price is a one-time snapshot
// (no tracking). Image cached as bytes so it survives remote URL expiry.

import Foundation

public struct ProductInfo: Codable, Equatable {
    public var name: String
    public var brand: String?
    public var priceText: String?     // formatted, e.g. "€42.00"
    public var currency: String?      // ISO code when available, e.g. "EUR"
    public var availability: String?  // e.g. "in stock"
    public var imageData: Data?       // cached product image bytes

    public init(name: String, brand: String? = nil, priceText: String? = nil,
                currency: String? = nil, availability: String? = nil, imageData: Data? = nil) {
        self.name = name
        self.brand = brand
        self.priceText = priceText
        self.currency = currency
        self.availability = availability
        self.imageData = imageData
    }
}
