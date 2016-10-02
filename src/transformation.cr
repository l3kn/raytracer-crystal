require "./mat4x4"

class TransformationWrapper < FiniteHitable
  # NOTE: The matrix in @transformation is from world to object space
  def initialize(@object : FiniteHitable, @transformation : Transformation)
    @bounding_box = transformation.object_to_world(@object.bounding_box)
  end

  def hit(ray : Ray, t_min : Float, t_max : Float)
    new_ray = @transformation.world_to_object(ray)
    hit = @object.hit(new_ray, t_min, t_max)

    if hit
      HitRecord.new(
        hit.t,
        @transformation.object_to_world(hit.point),
        @transformation.object_to_world(hit.normal),
        hit.material,
        hit.u, hit.v
      )
    else
      nil
    end
  end
end

class Transformation
  RADIANTS = (Math::PI / 180)
  ID = self.new(
    Mat4x4.new([
      [1.0, 0.0, 0.0, 0.0],
      [0.0, 1.0, 0.0, 0.0],
      [0.0, 0.0, 1.0, 0.0],
      [0.0, 0.0, 0.0, 1.0]
    ])
  )

  property matrix : Mat4x4
  property inverse : Mat4x4

  def initialize(@matrix)
    @inverse = @matrix.invert
  end

  def initialize(@matrix, @inverse)
  end

  def world_to_object(point_or_vector : (Point | Vector))
    @matrix * point_or_vector
  end

  def object_to_world(point_or_vector : (Point | Vector))
    @inverse * point_or_vector
  end

  def world_to_object(normal : Normal)
    # For normals the transformation
    # works the other way around
    # and the matrix is transposed,
    # but that fact is hidden in the `Mat4x4.*(other : Normal)` functon
    @inverse * normal
  end

  def object_to_world(normal : Normal)
    @matrix * normal
  end

  def world_to_object(ray : Ray)
    Ray.new(world_to_object(ray.origin), world_to_object(ray.direction))
  end

  def object_to_world(ray : Ray)
    Ray.new(object_to_world(ray.origin), object_to_world(ray.direction))
  end

  def object_to_world(box : AABB)
    # An `AABB` box
    # can be defined by a center point `c`
    # and an offset vector `o` that is positive in all its components.
    #
    # This way `@min = c - o` and `@max = c + o`
    #
    # If we were to apply a transformation matrix `M` to the box,
    # we would need to recalculate all `@min` and `@max` like this:
    #
    # ```
    # new_box = AABB.new(
    #   min( M * (c +- o) ),
    #   max( M * (c +- o) )
    # )
    # ```
    #
    # where `(c +- o)` is short for
    # `Point.new(c_x +- o_x, c_y +- o_y, c_z +- o_z)`,
    # meaning all 2*2*2 = 8 different possible points
    #
    # This way we would need to do 16 (or 8, if we use a combined min-max function)
    # Matrix-Point multiplications.
    #
    # `M * (c +- o)` is equivalent to
    # ```
    #   M[0...3, 0] * (c.x +- o.x)
    # + M[0...3, 1] * (c.y +- o.y)
    # + M[0...3, 2] * (c.z +- o.z)
    # + M[0...3, 3]
    # ```
    # where `M[0...3, n]` denotes the (first 3 rows of the) n-th column of the matrix
    # 
    # Using the equality from above
    # and the fact that min((a +- b) + (c +- d)) == min(a +- b) + min(c +- d),
    # we can turn `min( M * (c +- o) )` (and analogously `max(...)`) into
    #
    # ```
    #   min(M[0...3, 0] * (c.x +- o.x))
    # + min(M[0...3, 1] * (c.y +- o.y))
    # + min(M[0...3, 2] * (c.z +- o.z))
    # + M[0...3, 3]
    # ```
    # which uses only 12 (or 6) vector multiplications
    # and is (according to some quick benchmarks)
    # ~15x faster

    # In this code we assume,
    # that the last row of the inverse is (0, 0, 0, 1)^T
    if @inverse[3, 0] != 0.0 || @inverse[3, 1] != 0.0 ||
        @inverse[3, 2] != 0.0 || @inverse[3, 3] != 1.0
      raise "Unexpected transformation matrix format: #{@inverse.inspect}"
    end
    
    center = box.centroid
    offset = box.max - center

    tmp = center.x - offset.x
    a_1 = Point.new(@inverse[0, 0] * tmp, @inverse[1, 0] * tmp, @inverse[2, 0] * tmp)

    tmp = center.x + offset.x
    a_2 = Point.new(@inverse[0, 0] * tmp, @inverse[1, 0] * tmp, @inverse[2, 0] * tmp)

    tmp = center.y - offset.y
    b_1 = Point.new(@inverse[0, 1] * tmp, @inverse[1, 1] * tmp, @inverse[2, 1] * tmp)

    tmp = center.y + offset.y
    b_2 = Point.new(@inverse[0, 1] * tmp, @inverse[1, 1] * tmp, @inverse[2, 1] * tmp)

    tmp = center.z - offset.z
    c_1 = Point.new(@inverse[0, 2] * tmp, @inverse[1, 2] * tmp, @inverse[2, 2] * tmp)

    tmp = center.z + offset.z
    c_2 = Point.new(@inverse[0, 2] * tmp, @inverse[1, 2] * tmp, @inverse[2, 2] * tmp)

    rest = Point.new(@inverse[0, 3], @inverse[1, 3], @inverse[2, 3])

    AABB.new(
      a_1.min(a_2) + b_1.min(b_2) + c_1.min(c_2) + rest,
      a_1.max(a_2) + b_1.max(b_2) + c_1.max(c_2) + rest
    )
  end

  def *(other : Transformation)
    Transformation.new(
      @matrix * other.matrix,
      other.inverse * @inverse
    )
  end

  def swaps_handedness?
    det = ((@matrix[0, 0] *
            (@matrix[1, 1] * @matrix[2, 2] -
             @matrix[1, 2] * @matrix[2, 1])) -
           (@matrix[0, 1] *
             (@matrix[1, 0] * @matrix[2, 2] -
              @matrix[1, 2] * @matrix[2, 0])) +
           (@matrix[0, 2] *
             (@matrix[1, 0] * @matrix[2, 1] -
              @matrix[1, 1] * @matrix[2, 0])))

    det < 0.0
  end

  def self.translation(offset)
    Transformation.new(
      Mat4x4.new(
        1.0, 0.0, 0.0, offset.x,
        0.0, 1.0, 0.0, offset.y,
        0.0, 0.0, 1.0, offset.z,
        0.0, 0.0, 0.0, 1.0
      ),
      Mat4x4.new(
        1.0, 0.0, 0.0, -offset.x,
        0.0, 1.0, 0.0, -offset.y,
        0.0, 0.0, 1.0, -offset.z,
        0.0, 0.0, 0.0, 1.0
      )
    )
  end

  def self.scaling(scale)
    Transformation.new(
      Mat4x4.new(
        scale.x, 0.0, 0.0, 0.0,
        0.0, scale.y, 0.0, 0.0,
        0.0, 0.0, scale.z, 0.0,
        0.0, 0.0, 0.0, 1.0
      ),
      Mat4x4.new(
        1.0 / scale.x, 0.0, 0.0, 0.0,
        0.0, 1.0 / scale.y, 0.0, 0.0,
        0.0, 0.0, 1.0 / scale.z, 0.0,
        0.0, 0.0, 0.0, 1.0
      )
    )
  end

  def self.rotation_x(angle)
    sin = Math.sin(angle * RADIANTS)
    cos = Math.cos(angle * RADIANTS)

    matrix = Mat4x4.new(
      1.0, 0.0,  0.0, 0.0,
      0.0, cos, -sin, 0.0,
      0.0, sin,  cos, 0.0,
      0.0, 0.0, 0.0, 1.0
    )

    Transformation.new(matrix, matrix.transpose)
  end

  def self.rotation_y(angle)
    sin = Math.sin(angle * RADIANTS)
    cos = Math.cos(angle * RADIANTS)

    matrix = Mat4x4.new(
       cos, 0.0, sin, 0.0,
       0.0, 1.0, 0.0, 0.0,
      -sin, 0.0, cos, 0.0,
       0.0, 0.0, 0.0, 1.0
    )

    Transformation.new(matrix, matrix.transpose)
  end

  def self.rotation_z(angle)
    sin = Math.sin(angle * RADIANTS)
    cos = Math.cos(angle * RADIANTS)

    matrix = Mat4x4.new(
      cos, -sin, 0.0, 0.0,
      sin,  cos, 0.0, 0.0,
      0.0,  0.0, 1.0, 0.0,
      0.0,  0.0, 0.0, 1.0
    )

    Transformation.new(matrix, matrix.transpose)
  end

  def self.rotation(angle, axis)
    axis = axis.normalize
    sin = Math.sin(angle * RADIANTS)
    cos = Math.cos(angle * RADIANTS)

    matrix = Matrix4x4.new

    matrix[0, 0] = axis.x * axis.x + (1.0 - axis.x * axis.x) * cos
    matrix[0, 1] = axis.x * axis.y * (1.0 - cos) - axis.z * sin
    matrix[0, 2] = axis.x * axis.z * (1.0 - cos) + axis.y * sin
    matrix[0, 3] = 0.0

    matrix[1, 0] = axis.x * axis.y * (1.0 - cos) + axis.z * sin
    matrix[1, 1] = axis.y * axis.y + (1.0 - axis.y * axis.y) * cos
    matrix[1, 2] = axis.y * axis.z * (1.0 - c) - axis.x * sin
    matrix[1, 3] = 0.0

    matrix[2, 0] = axis.x * axis.z * (1.0 - cos) - axis.y * sin
    matrix[2, 1] = axis.y * axis.z * (1.0 - cos) + axis.x * sin
    matrix[2, 2] = axis.y * axis.z * (1.0 - axis.z * axis.z) * cos
    matrix[2, 3] = 0.0

    matrix[3, 0] = 0.0
    matrix[3, 1] = 0.0
    matrix[3, 2] = 0.0
    matrix[3, 3] = 1.0

    Transformation.new(matrix, matrix.transpose)
  end

  def self.look_at(look_from, look_at, up)
    matrix = Matrix4x4.new
    dir = (look_at - look_from).normalize
    left = up.normalize.cross(dir)
    newUp = dir.cross(left)

    matrix = Matrix4x4.new

    matrix[0, 0] = left.x
    matrix[1, 0] = left.y
    matrix[2, 0] = left.z
    matrix[3, 0] = 0.0
    matrix[0, 1] = newUp.x
    matrix[1, 1] = newUp.y
    matrix[2, 1] = newUp.z
    matrix[3, 1] = 0.0
    matrix[0, 2] = dir.x
    matrix[1, 2] = dir.y
    matrix[2, 2] = dir.z
    matrix[3, 2] = 0.0
    matrix[0, 3] = pos.x
    matrix[1, 3] = pos.y
    matrix[2, 3] = pos.z
    matrix[3, 3] = 1.0
  end
end
