class Sample
  getter mean : Color
  getter n_variance : Color
  getter n : Int32

  def initialize
    @mean = Color::BLACK
    @n_variance = Color::BLACK
    @n = 0
  end

  def add(sample : Color)
    @n += 1
    new_mean = @mean + (sample - @mean)*(1.0 / @n)
    # TODO: Support variance
    # new_n_var = @n_variance + (sample - @mean) * (sample - new_mean)
    @mean = new_mean
    # @n_variance = new_n_var
  end

  def reset
    @n = 0
    @mean = Color::BLACK
    @n_variance = Color::BLACK
  end
end

class Visualisation
  def initialize(@width : Int32, @height : Int32)
    @layers = {} of Symbol => Array(Float64)
    @max = {} of Symbol => Float64
  end

  def add_layer(name : Symbol)
    @layers[name] = Array(Float64).new(@width * @height, 0.0)
    @max[name] = Float64::MIN
  end

  def set(name : Symbol, x : Int32, y : Int32, value : Float64)
    @layers[name][@width * y + x] = value
    @max[name] = max(@max[name], value)
  end

  def write(name : Symbol, filename : String)
    canvas = StumpyPNG::Canvas.new(@width, @height + 16) do |x, y|
      if y < @height
        value = @layers[name][@width * y + x] / @max[name]
        StumpyPNG::RGBA.from_relative(
          value,
          value,
          value,
          1.0
        )
      else
        StumpyPNG::RGBA.from_hex("#ffffff")
      end
    end

    # StumpyUtils.text(canvas, 16, @height,
    #   "#{name.to_s} (max: #{@max[name].round(2)})",
    #   StumpyPNG::RGBA.from_hex("#000000"),
    #   StumpyPNG::RGBA.from_hex("#ffffff"),
    #   size: 2)
    StumpyPNG.write(canvas, filename)
  end
end
