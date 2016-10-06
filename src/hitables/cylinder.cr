require "../hitable"

class Cylinder < FiniteHitable
  property y_min : Float64, y_max : Float64, radius
  @phi_max : Float64
  @inv_phi_max : Float64
  @inv_length : Float64

  def initialize(y1, y2, @radius : Float64, @material : Material)
    @y_min = min(y1, y2)
    @y_max = max(y1, y2)

    p1 = Point.new(-@radius, -@radius, @y_min)
    p2 = Point.new( @radius,  @radius, @y_max)
    @bounding_box = AABB.new(p1, p2)

    @phi_max = 360.0 * RADIANTS
    @inv_phi_max = 1.0 / @phi_max
    @inv_length = 1.0 / (@y_max - @y_min)
  end

  def hit(ray, t_min, t_max)
    a = (ray.direction.x * ray.direction.x) + (ray.direction.z * ray.direction.z)
    b = 2 * ((ray.direction.x * ray.origin.x) + (ray.direction.z * ray.origin.z))
    c = (ray.origin.x * ray.origin.x) + (ray.origin.z * ray.origin.z) - (@radius * @radius)

    ts = solve_quadratic(a, b, c)
    return nil if ts.nil?

    t0, t1 = ts
    return nil if t0 > t_max || t1 < t_min

    y0 = ray.origin.y + t0 * ray.direction.y
    y1 = ray.origin.y + t1 * ray.direction.y

    if y0 < @y_min
      # Bottom cap
      return nil if y0 < @y_min # Ray misses the cylinder entirely

      t_hit = t0 + (t1 - t0) * (y0 - @y_min) / (y0 - y1)
      point = ray.point_at_parameter(t_hit)
      normal = Normal.new(0.0, -1.0, 0.0)

      # TODO: calculate correct uv coordinates
    elsif y0 >= @y_min && y0 <= @y_max
      # Cylinder body
      t_hit = t0
      point = ray.point_at_parameter(t_hit)
      normal = Vector.new(point.x, 0.0, point.z).to_normal
    else
      # Top cap
      return nil if y1 > @y_max # Ray misses the cylinder entirely

      t_hit = t0 + (t1 - t0) * (y0 - @y_max) / (y0 - y1)
      point = ray.point_at_parameter(t_hit)
      normal = Normal.new(0.0, 1.0, 0.0)

      # TODO: calculate correct uv coordinates
    end

    phi = Math.atan2(point.z, point.x)
    phi += 2.0 * Math::PI if phi < 0.0

    u = phi * @inv_phi_max
    v = (point.z - @y_min) * @inv_length

    return HitRecord.new(t_hit, point, normal, @material, u, v)
  end
end
