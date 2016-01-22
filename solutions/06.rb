module TurtleGraphics
  class Matrix
    attr_reader :rows, :column_count, :row_count

    def initialize(row_count, column_count = row_count)
      @rows = Array.new(row_count) { Array.new(column_count) { 0 } }
      @column_count = column_count
      @row_count = row_count
    end
  end

  class Turtle
    DIRECTIONS = [:left, :up, :right, :down].freeze

    def initialize(row_count, column_count)
      @matrix = Matrix.new(row_count, column_count)
      look(:right)
    end

    def draw(canvas = nil)
      self.instance_eval(&Proc.new) if block_given?
      canvas != nil ? canvas.build(@matrix) : @matrix.rows
    end

    private

    def move
      spawn_at(0, 0) if @x.nil? and @y.nil?

      move_at_direction
      @x = @x < 0 ? @matrix.row_count - 1 : @x % @matrix.row_count
      @y = @y < 0 ? @matrix.column_count - 1 : @y % @matrix.column_count
      @matrix.rows[@x][@y] += 1
    end

    def move_at_direction
      case @direction
        when 0 then @y -= 1
        when 1 then @x -= 1
        when 2 then @y += 1
        when 3 then @x += 1
      end
    end

    def turn_left
      @direction = @direction == 0 ? DIRECTIONS.length - 1 : @direction - 1
    end

    def turn_right
      @direction = @direction == DIRECTIONS.length - 1 ? 0 : @direction + 1
    end

    def spawn_at(row, column)
      @x = row
      @y = column
      @matrix.rows[@x][@y] += 1
    end

    def look(direction)
      @direction = DIRECTIONS.index(direction)
    end
  end

  module Canvas
    def max_frequency
      @matrix.rows.collect { |row| row.max }.max
    end

    class ASCII
      include Canvas

      def initialize(symbols)
        @symbols = symbols
      end

      def build(matrix)
        @matrix = matrix
        matrix.rows.map { |row| join_row(row) }.join("\n")
      end

      private

      def join_row(row)
        row.map { |cell| symbol(cell) }.join
      end

      def symbol(cell)
        index = symbol_index(cell)
        (index == @symbols.length) ? @symbols.last : @symbols[index]
      end

      def symbol_index(cell)
        interval = (1.0 / max_frequency).to_f
        cell / (max_frequency * interval)
      end
    end

    class HTML
      include Canvas

      def initialize(pixel_size)
        @pixel_size = pixel_size
      end

      def build(matrix)
        @matrix = matrix

        %{
        <!DOCTYPE html>
        <html>
          #{head}
          #{body(matrix)}
        </html>
        }
      end

      private

      def head
        %{
        <head>
          <title>Turtle graphics</title>

          <style>
            table {
              border-spacing: 0;
            }

            tr {
              padding: 0;
            }

            td {
              width: #{@pixel_size}px;
              height: #{@pixel_size}px;

              background-color: black;
              padding: 0;
            }
          </style>
        </head>
        }
      end

      def body(matrix)
        %{
          <body>
            #{table(matrix)}
          </body>
        }
      end

      def table(matrix)
        rows = matrix.rows.map { |row| join_row(row) }.join
        "<table>#{rows}</table>"
      end

      def join_row(row)
        cells = row.map { |cell| join_cell(cell) }.join
        "<tr>#{cells}</tr>"
      end

      def join_cell(cell)
        format('<td style="opacity: %.2f"></td>', intensity(cell))
      end

      def intensity(cell)
        cell.to_f / max_frequency
      end
    end
  end
end