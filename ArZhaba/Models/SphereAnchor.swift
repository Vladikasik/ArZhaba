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
        case colorComponents
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.radius = aDecoder.decodeFloat(forKey: CodingKeys.radius.rawValue)
        
        if let components = aDecoder.decodeObject(of: [NSArray.self], forKey: CodingKeys.colorComponents.rawValue) as? [CGFloat],
           components.count == 4 {
            self.color = UIColor(red: components[0], green: components[1], blue: components[2], alpha: components[3])
        } else {
            self.color = .red
        }
        
        super.init(coder: aDecoder)
    }
    
    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        
        aCoder.encode(radius, forKey: CodingKeys.radius.rawValue)
        
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let components: [CGFloat] = [r, g, b, a]
        
        aCoder.encode(components, forKey: CodingKeys.colorComponents.rawValue)
    }
} 