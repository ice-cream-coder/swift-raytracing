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
        let clamped = simd.clamp(self, min: 0.0, max: 0.999)
        return "\(Int(256.0 * clamped.x)) \(Int(256.0 * clamped.y)) \(Int(256.0 * clamped.z))"
    }

    func colorString(samples: Int) -> String {
        (self / Double(samples)).squareRoot().colorString
    }

    func dot(_ o: SIMD3<Scalar>) -> Scalar {
        simd.dot(self, o)
    }

    func cross(_ o: SIMD3<Scalar>) -> SIMD3<Scalar> {
        simd.cross(self, o)
    }

    var isNearZero: Bool {
        let s = 1e-8
        return abs(x) < s && abs(y) < s && abs(z) < s
    }

    func reflect(normal: Self) -> Self {
        self - 2 * self.dot(normal) * normal
    }

    static func random() -> Self {
        Self(x: Double.random(in: 0.0..<1.0),
             y: Double.random(in: 0.0..<1.0),
             z: Double.random(in: 0.0..<1.0))
    }

    static func random(min: Double, max: Double) -> Self {
        Self(x: Double.random(in: min...max),
             y: Double.random(in: min...max),
             z: Double.random(in: min...max))
    }

    static func randomInUnitSphere() -> Self {
        while(true) {
            let point = random(min: -1.0, max: 1.0)
            if point.lengthSquared <= 1 {
                return point
            }
        }
    }

    static func randomUnitVector() -> Self {
        randomInUnitSphere().unitVector
    }

    func randomInHemisphere() -> Self {
        let inUnitSphere = Self.randomInUnitSphere()
        if inUnitSphere.dot(self) > 0.0 {
            return inUnitSphere
        } else {
            return -inUnitSphere
        }
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
    static let black: Color = .init(r: 0.0, g: 0.0, b: 0.0)
    static let red: Color = .init(r: 1.0, g: 0.0, b: 0.0)
}

struct Ray {
    let origin: Point
    let direction: Vector

    func at(_ t: Double) -> Point {
        origin + t * direction
    }
}

struct HitRecord {
    let point: Point
    let normal: Vector
    var material: Material
    let t: Double
    let frontFace: Bool

    init(ray: Ray, t: Double, outwardNormal: Vector, material: Material) {
        self.t = t
        point = ray.at(t)
        frontFace = ray.direction.dot(outwardNormal) < 0
        normal = frontFace ? outwardNormal : -outwardNormal
        self.material = material
    }
}

protocol Hittable {
    func hit(ray: Ray, tMin: Double, tMax: Double) -> HitRecord?
}

protocol Material: AnyObject {
    func scatter(ray: Ray, hit: HitRecord) -> (attenuation: Color, scattered: Ray)?
}

class Lambertian: Material {
    let albedo: Color

    init(albedo: Color) {
        self.albedo = albedo
    }

    func scatter(ray: Ray, hit: HitRecord) -> (attenuation: Color, scattered: Ray)? {
        var scatterDirection = hit.normal + Vector.randomUnitVector()

        if scatterDirection.isNearZero {
            scatterDirection = hit.normal
        }

        return (
            attenuation: albedo,
            scattered: Ray(origin: hit.point, direction: scatterDirection)
        )
    }
}

class Metal : Material {
    let albedo: Color
    let fuzz: Double

    init(albedo: Color, fuzz: Double) {
        self.albedo = albedo
        self.fuzz = fuzz
    }

    func scatter(ray: Ray, hit: HitRecord) -> (attenuation: Color, scattered: Ray)? {
        let reflected = ray.direction.unitVector.reflect(normal: hit.normal)
        let scattered = Ray(origin: hit.point, direction: reflected + fuzz * Vector.randomInUnitSphere())
        if dot(scattered.direction, hit.normal) > 0 {
            return (
                attenuation: albedo,
                scattered: scattered
            )
        } else {
            return nil
        }
    }
}

struct Sphere: Hittable {
    let center: Point
    let radius: Double
    let material: Material

    func hit(ray: Ray, tMin: Double, tMax: Double) -> HitRecord? {
        let originToCenter = ray.origin - center;
        let a = ray.direction.lengthSquared
        let half_b = originToCenter.dot(ray.direction)
        let c = originToCenter.lengthSquared - radius * radius
        let discriminant = half_b * half_b - a * c
        guard discriminant > 0.0 else { return nil }
        let sqrtDiscriminant = sqrt(discriminant)

        var root = (-half_b - sqrtDiscriminant) / a
        if root < tMin || root > tMax {
            root = (-half_b + sqrtDiscriminant) / a
            if root < tMin || root > tMax {
                return nil
            }
        }
        let hitPoint = ray.at(root)
        return HitRecord(ray: ray, t: root, outwardNormal: (hitPoint - center) / radius, material: material)
    }
}

struct HittableList: Hittable {
    var objects = [Hittable]()

    func hit(ray: Ray, tMin: Double, tMax: Double) -> HitRecord? {
        var closestRecord: HitRecord?
        for object in objects {
            let tMax = closestRecord?.t ?? tMax
            if let hitRecord = object.hit(ray: ray, tMin: tMin, tMax: tMax) {
                closestRecord = hitRecord
            }
        }
        return closestRecord
    }
}

struct Camera {
    let origin: Point
    let lowerLeftCorner: Point
    let horizontal: Vector
    let vertical: Vector

    init() {
        let aspectRatio = 16.0 / 9.0
        let viewportHeight = 2.0;
        let viewportWidth = aspectRatio * viewportHeight;
        let focalLength = 1.0;

        origin = Point(x: 0, y: 0, z: 0)
        horizontal =  Vector(x: viewportWidth, y: 0, z: 0)
        vertical = Vector(x: 0, y: viewportHeight, z: 0)
        lowerLeftCorner = origin - horizontal / 2 - vertical / 2 - Vector(x: 0, y: 0, z: focalLength)
    }

    func getRay(u: Double, v: Double) -> Ray {
        Ray(origin: origin, direction: lowerLeftCorner + u * horizontal + v * vertical - origin)
    }
}

let groundMaterial = Lambertian(albedo: .init(r: 0.8, g: 0.8, b: 0.0))
let centerMaterial = Lambertian(albedo: .init(r: 0.7, g: 0.3, b: 0.3))
let leftMaterial = Metal(albedo: .init(r: 0.8, g: 0.8, b: 0.3), fuzz: 0.3)
let rightMaterial = Metal(albedo: .init(r: 0.8, g: 0.6, b: 0.2), fuzz: 1.0)

let world = HittableList(objects: [
    Sphere(center: Point(x: 0.0, y: -100.5, z: -1.0), radius: 100.0, material: groundMaterial),
    Sphere(center: Point(x: 0.0, y: 0.0, z: -1.0), radius: 0.5, material: centerMaterial),
    Sphere(center: Point(x: -1.0, y: 0.0, z: -1.0), radius: 0.5, material: leftMaterial),
    Sphere(center: Point(x: 1.0, y: 0.0, z: -1.0), radius: 0.5, material: rightMaterial),
])

func color(for ray: Ray, depth: Int) -> Color {
    guard depth > 0 else { return Color.black }
    if let hit = world.hit(ray: ray, tMin: 0.001, tMax: Double.infinity) {
        if let (attenuation, scattered) = hit.material.scatter(ray: ray, hit: hit) {
            return attenuation * color(for: scattered, depth: depth - 1)
        } else {
            return Color.black
        }
    } else {
        let t = 0.5 * (ray.direction.unitVector.y + 1.0)
        return (1.0 - t) * Color.white + t * Color(r: 0.5, g: 0.7, b: 1.0)
    }
}


// Image
let aspectRatio = 16.0 / 9.0
let imageWidth = 400
let imageHeight = Int(Double(imageWidth) / aspectRatio)
let samplesPerPixel = 100
let maxDepth = 50

// Camera

let camera = Camera()

// Render

print("P3\n\(imageWidth) \(imageHeight)\n255")
for _j in 0..<imageHeight {
    let j = imageHeight - 1 - _j
    printErr("\rScanlines remaining: \(j) ")
    for i in 0..<imageWidth {
        var pixelColor = Color(r: 0.0, g: 0.0, b: 0.0)
        for _ in 0..<samplesPerPixel {
            let u = (Double(i) + Double.random(in: 0..<1)) / Double(imageWidth - 1)
            let v = (Double(j) + Double.random(in: 0..<1)) / Double(imageHeight - 1)

            let ray = camera.getRay(u: u, v: v)
            pixelColor += color(for: ray, depth: maxDepth)
        }
        print(pixelColor.colorString(samples: samplesPerPixel))
    }
}
printErr("\nDone.\n")
