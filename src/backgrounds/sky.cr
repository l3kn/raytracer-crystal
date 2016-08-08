require "../background"

class SkyBackground < Background
  def get(ray)
    t = 0.5 * (ray.direction.normalize.y + 1.0)
    Vec3.new(1.0)*(1.0 - t) + Vec3.new(0.5, 0.7, 1.0)*t
  end
end