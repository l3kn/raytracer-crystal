require "./vec3"
require "./ray"
require "./hitable"
require "./hitable/*"
require "./camera"
require "./helper"
require "./material"
require "./material/*"
require "./texture"
require "./aabb"

class Raytracer
  property width, height

  def initialize(@width = 800, @height = 400)
  end

  def render(world, camera, samples, filename)
    file = File.open(filename, "w")

    file.puts "P3"
    file.puts "#{width} #{height}"
    file.puts "255"

    samples_sqrt = Math.sqrt(samples).ceil

    (0...@height).reverse_each do |y|
      (0...@width).each do |x|
        col = Vec3.new(0.0)

        (0...samples_sqrt).each do |i|
          (0...samples_sqrt).each do |j|
            off_x = (i + rand) / samples_sqrt
            off_y = (j + rand) / samples_sqrt

            u = (x + off_x).to_f / @width
            v = (y + off_y).to_f / @height

            ray = camera.get_ray(u, v)

            col += color(ray, world)
          end
        end

        col /= (samples_sqrt * samples_sqrt)
        col *= 255.99

        # Cap color values at 255 so that lights (albedo > 1.0)
        # do not lead to corrupted ppm files
        file.print "#{min(col.x.to_i, 255)} "
        file.print "#{min(col.y.to_i, 255)} "
        file.print "#{min(col.z.to_i, 255)}\n"
      end

      puts "Traced line #{@height - y} / #{@height}"
    end

    file.close
  end

  RECURSION_LIMIT = 10

  def color(ray, world, recursion_level = 0)
    hit = world.hit(ray, 0.0001, 9999.9)
    if hit
      scatter = hit.material.scatter(ray, hit)
      emitted = hit.material.emitted(hit.point)
      if scatter && recursion_level < RECURSION_LIMIT
        emitted + scatter[1] * color(scatter[0], world, recursion_level + 1)
      else
        emitted
      end
    else
      # "Sky":
      #   t = 0.5 * (ray.direction.normalize.y + 1.0)
      #   Vec3.new(1.0)*(1.0 - t) + Vec3.new(0.5, 0.7, 1.0)*t
      Vec3.new(0.0)
    end
  end
end
