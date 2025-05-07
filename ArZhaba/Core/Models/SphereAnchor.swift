import Foundation
import ARKit

/// Custom anchor representing a sphere in AR space
class SphereAnchor: ARAnchor {
    static let identifier = "SphereAnchor"
    let radius: Float
    let color: UIColor
    
    init(transform: simd_float4x4, radius: Float = 0.025, color: UIColor = .red) {
        self.radius = radius
        self.color = color
        super.init(name: SphereAnchor.identifier, transform: transform)
    }
    
    required init(anchor: ARAnchor) {
        if let sphereAnchor = anchor as? SphereAnchor {
            self.radius = sphereAnchor.radius
            self.color = sphereAnchor.color
        } else {
            self.radius = 0.025
            self.color = .red
        }
        super.init(anchor: anchor)
    }
    
    override class var supportsSecureCoding: Bool {
        return true
    }
    
    enum CodingKeys: String, CodingKey {
        case radius
        case red
        case green
        case blue
        case alpha
        case identifier
        case name
    }
    
    required init?(coder aDecoder: NSCoder) {
        // Handle various encoding formats for radius
        let radiusValue: Float
        
        if aDecoder.containsValue(forKey: CodingKeys.radius.rawValue) {
            // Try different decoding approaches
            if let data = aDecoder.decodeObject(forKey: CodingKeys.radius.rawValue) as? NSNumber {
                radiusValue = Float(data.doubleValue)
            } else if let data = aDecoder.decodeObject(forKey: CodingKeys.radius.rawValue) as? Double {
                radiusValue = Float(data)
            } else {
                // Try regular Float decoding
                radiusValue = aDecoder.decodeFloat(forKey: CodingKeys.radius.rawValue)
            }
            
            // Validate the value is reasonable
            if radiusValue <= 0 || radiusValue > 1.0 {
                self.radius = 0.025 // Default value
            } else {
                self.radius = radiusValue
            }
        } else {
            // Default value if no radius found
            self.radius = 0.025
        }
        
        // Color decoding with error handling
        let red = aDecoder.decodeFloat(forKey: CodingKeys.red.rawValue)
        let green = aDecoder.decodeFloat(forKey: CodingKeys.green.rawValue)
        let blue = aDecoder.decodeFloat(forKey: CodingKeys.blue.rawValue)
        let alpha = aDecoder.decodeFloat(forKey: CodingKeys.alpha.rawValue)
        
        let safeCGRed = CGFloat(max(0, min(1, red)))
        let safeCGGreen = CGFloat(max(0, min(1, green)))
        let safeCGBlue = CGFloat(max(0, min(1, blue)))
        let safeCGAlpha = CGFloat(max(0, min(1, alpha)))
        
        self.color = UIColor(red: safeCGRed, green: safeCGGreen, blue: safeCGBlue, alpha: safeCGAlpha)
        
        // Don't decode identifier or name - use parent class init instead
        super.init(coder: aDecoder)
    }
    
    override func encode(with aCoder: NSCoder) {
        // Call super first to let the parent class handle all basic properties
        super.encode(with: aCoder)
        
        // Only encode our custom properties, not the identifier or name
        aCoder.encode(radius > 0 ? radius : 0.025, forKey: CodingKeys.radius.rawValue)
        
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        if !color.getRed(&r, green: &g, blue: &b, alpha: &a) {
            r = 1.0
            g = 0.0
            b = 0.0
            a = 1.0
        }
        
        aCoder.encode(Float(max(0, min(1, r))), forKey: CodingKeys.red.rawValue)
        aCoder.encode(Float(max(0, min(1, g))), forKey: CodingKeys.green.rawValue)
        aCoder.encode(Float(max(0, min(1, b))), forKey: CodingKeys.blue.rawValue)
        aCoder.encode(Float(max(0, min(1, a))), forKey: CodingKeys.alpha.rawValue)
        
        // Don't re-encode identifier or name - let parent class handle it
    }
} 