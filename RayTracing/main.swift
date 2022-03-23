import Foundation
import simd


typealias Color = SIMD3<Double>
typealias Point = SIMD3<Double>
typealias Vector = SIMD3<Double>

final class StandardErrorOutputStream: TextOutputStream {
    func write(_ string: String) {
        FileHandle.standardError.write(Data(string.utf8))
    }
}

var outputStream = StandardErrorOutputStream()
func printErr(_ string: String) {
    print(string, to: &outputStream)
}


extension SIMD3 where Scalar == Double {
    var length: Double {
        sqrt(lengthSquared)
    }

    var lengthSquared: Double {
        dot(self)
    }

    var unitVector: Self {
        self / self.length
    }

    var colorString: String {
        "\(Int(255.999 * x)) \(Int(255.999 * y)) \(Int(255.999 * z))"
    }

    func dot(_ o: SIMD3<Scalar>) -> Scalar {
        simd.dot(self, o)
    }

    func cross(_ o: SIMD3<Scalar>) -> SIMD3<Scalar> {
        simd.cross(self, o)
    }
}

extension Color {
    init(r: Scalar, g: Scalar, b: Scalar) {
        self.init(x: r, y: g, z: b)
    }

    var r: Scalar { x }
    var g: Scalar { y }
    var b: Scalar { z }

    static let white: Color = .init(r: 1.0, g: 1.0, b: 1.0)
    static let red: Color = .init(r: 1.0, g: 0.0, b: 0.0)
}

struct Ray {
    let origin: Point
    let direction: Vector

    func at(_ t: Double) -> Point {
        origin + t * direction
    }

    func hit(sphere: Sphere) -> Double? {
        let originToCenter = origin - sphere.center;
        let a = direction.lengthSquared
        let half_b = originToCenter.dot(direction)
        let c = originToCenter.lengthSquared - sphere.radius * sphere.radius
        let discriminant = half_b * half_b - a * c
        if discriminant < 0.0 {
            return nil
        } else {
            return (-half_b - sqrt(discriminant)) / a
        }
    }
}

struct Sphere {
    let center: Point
    let radius: Double
}

let sphere = Sphere(center: Point(x: 0, y: 0, z: -1), radius: 0.5)

func color(for ray: Ray) -> Color {

    if let t = ray.hit(sphere: sphere) {
        let normal = (ray.at(t) - sphere.center).unitVector
        return 0.5 * (normal + 1)
    } else {
        let t = 0.5 * (ray.direction.unitVector.y + 1.0)
        return (1.0 - t) * Color.white + t * Color(r: 0.5, g: 0.7, b: 1.0)
    }
}


// Image
let aspectRatio = 16.0 / 9.0
let imageWidth = 400
let imageHeight = Int(Double(imageWidth) / aspectRatio)

// Camera

let viewportHeight = 2.0;
let viewportWidth = aspectRatio * viewportHeight;
let focalLength = 1.0;

let origin = Point(x: 0, y: 0, z: 0)
let horizontal =  Vector(x: viewportWidth, y: 0, z: 0)
let vertical = Vector(x: 0, y: viewportHeight, z: 0)
let lowerLeftCorner = origin - horizontal / 2 - vertical / 2 - Vector(x: 0, y: 0, z: focalLength)

// Render

print("P3\n\(imageWidth) \(imageHeight)\n255")
for _j in 0..<imageHeight {
    let j = imageHeight - 1 - _j
    printErr("\rScanlines remaining: \(j) ")
    for i in 0..<imageWidth {
        let u = Double(i) / Double(imageWidth - 1)
        let v = Double(j) / Double(imageHeight - 1)
        let ray = Ray(origin: origin,
                      direction: lowerLeftCorner +
                      (u * horizontal) +
                      (v * vertical) -
                      origin)
        let pixelColor = color(for: ray)
        print(pixelColor.colorString)
    }
}
printErr("\nDone.\n")
