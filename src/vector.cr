require "./helper"

struct Vector < LA::AVector3
  define_class_methods
  define_dot(other_class: Normal)
  define_vector_op(:*)
  define_vector_op(:/)

  def to_normal
    inv = 1.0 / length
    Normal.new(self.x * inv, self.y * inv, self.z * inv)
  end

  # TODO, see Normal.to_normal
  def to_vector; self;
  end

  def to_point
    Point.new(@x, @y, @z)
  end

  define_vector_swizzling(2)
  define_vector_swizzling(3, signed: true)

  def to_tuple
    {@x, @y, @z}
  end

  def max(other : Float64)
    Vector.new(max(@x, other), max(@y, other), max(@z, other))
  end
end
