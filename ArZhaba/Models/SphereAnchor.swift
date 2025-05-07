import Foundation
import ARKit

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
    }
    
    required init?(coder aDecoder: NSCoder) {
        // Decode radius with a default value to handle potential missing data
        self.radius = aDecoder.containsValue(forKey: CodingKeys.radius.rawValue) ? 
                     aDecoder.decodeFloat(forKey: CodingKeys.radius.rawValue) : 0.025
        
        // More efficient color decoding - store components directly rather than as array
        let red = aDecoder.containsValue(forKey: CodingKeys.red.rawValue) ? 
                 CGFloat(aDecoder.decodeFloat(forKey: CodingKeys.red.rawValue)) : 1.0
        let green = aDecoder.containsValue(forKey: CodingKeys.green.rawValue) ? 
                   CGFloat(aDecoder.decodeFloat(forKey: CodingKeys.green.rawValue)) : 0.0
        let blue = aDecoder.containsValue(forKey: CodingKeys.blue.rawValue) ? 
                  CGFloat(aDecoder.decodeFloat(forKey: CodingKeys.blue.rawValue)) : 0.0
        let alpha = aDecoder.containsValue(forKey: CodingKeys.alpha.rawValue) ? 
                   CGFloat(aDecoder.decodeFloat(forKey: CodingKeys.alpha.rawValue)) : 1.0
        
        self.color = UIColor(red: red, green: green, blue: blue, alpha: alpha)
        
        super.init(coder: aDecoder)
    }
    
    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        
        // Encode the radius
        aCoder.encode(radius, forKey: CodingKeys.radius.rawValue)
        
        // More efficiently encode color components directly
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // Store as individual floats rather than an array to reduce overhead
        aCoder.encode(Float(r), forKey: CodingKeys.red.rawValue)
        aCoder.encode(Float(g), forKey: CodingKeys.green.rawValue)
        aCoder.encode(Float(b), forKey: CodingKeys.blue.rawValue)
        aCoder.encode(Float(a), forKey: CodingKeys.alpha.rawValue)
    }
} 