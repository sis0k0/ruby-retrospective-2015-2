class Spreadsheet
  DIGIT_PATTERN = /^\d+$/
  ROW_DELIMITER = /\n/
  CELL_DELIMITER = /\t|  /

  class Error < StandardError
    class InvalidCellIndexError
    end
  end

  def initialize(table = '')
    split_to_cells(table)
  end

  def empty?
    @cells.length == 0
  end

  def cell_at(index)
    cell = @cells.find { |cell| cell.at?(index) }
    raise Error, "Cell '#{index}' does not exist" unless cell
    cell.content
  end

  def [](index)
    cell = @cells.find { |cell| cell.at?(index) }
    raise Error, "Cell '#{index}' does not exist" unless cell
    cell.value
  end

  def to_s
    @rows.map.with_index { |row, index| row_to_s(row) }.join("\n")
  end

  private

  def row_to_s(row)
    row.map.with_index { |cell, index| cell.value }.join("\t")
  end

  def split_to_cells(table)
    @rows = table.strip.
      split(ROW_DELIMITER).
      map.with_index { |row_data, index| new_row(row_data, index) }

    @cells = @rows.flatten
  end

  def new_row(data, index)
    data.strip.
      split(CELL_DELIMITER).
      reject { |cell_content| cell_content == '' }.
      map.with_index do |cell_content, column_index|
        address = Address.new(index + 1, column_index + 1)
        Cell.new(self, address, cell_content.strip)
      end
  end

  class Cell
    attr_reader :content

    def initialize(parent, address, content)
      @parent = parent
      @address = address
      @content = content
    end

    def value
      Expression.new(content, @parent).value
    end

    def at?(index)
      @address.index == index
    end
  end

  class Address
    KEYS_COUNT = 26

    def initialize(*args)
      if args.length == 2
        @row = args.first.to_i
        @column = args.last.to_i
      elsif args.length == 1
        @index = args.first
      end
    end

    def index
      @index.nil? ? column_index << @row.to_s : @index
    end

    def ==(index)
      raise Error::InvalidCellIndexError, "Invalid cell index \
'#{index}'" unless valid?(index)
      self.index == index
    end

    def valid?(index = @index)
      parts = index.split(DIGIT_PATTERN)
      parts.length == 2 and valid_column? parts.first and valid_row? parts.last
    end

    private

    def valid_column?(column_index)
      column_index.
        each_char.
        all? { |ch| 'A' <= ch.to_s and ch.to_s <= 'Z' }
    end

    def valid_row?(row)
      row.match(DIGIT_PATTERN)
    end

    def column_index
      col, index = @column, ''

      while col > 0
        letter_index = (col / KEYS_COUNT > 0) ? (col / KEYS_COUNT) : col
        index << column_key(letter_index)
        col -= letter_index * KEYS_COUNT
      end
      index
    end

    # Get the nth letter in the aplhabet
    def column_key(n)
      ('A'.ord + n - 1).chr
    end
  end

  class Expression
    def initialize(content, table)
      @content = content
      @table = table
    end

    def value
      return @content unless formula?

      address = Address.new(@content[1..-1])
      address.valid? ? @table[address.index] : calculate
    end

    private

    def formula?
      @content[0] == '='
    end

    def calculate
      FormulaFactory.calculate(method_name, args)
    end

    def method_name
      if @content.index('(').nil? or @content.index(')').nil?
        raise Error, "Invalid expression '#{@content[1..-1]}'"
      end

      name = @content.slice(1..(@content.index('(') - 1))
      case name
      when 'ADD', 'MULTIPLY', 'SUBTRACT', 'DIVIDE', 'MOD' then name.to_sym
      else raise Error, "Unknown function '#{name}'"
      end
    end

    def args
      name_end_index = @content.index('(')

      @content.slice((name_end_index + 1)..-2).
        split(',').
        map { |argument| parse(argument) }
    end

    def parse(argument)
      argument.strip!
      result = argument_to_float(argument, argument.split('.'))
      begin
        result = @table[argument].to_f if result.nil?
      rescue Error::InvalidCellIndexError
        raise Error, "Invalid expression '#{@content}'"
      end
      result.nil? ? raise(Error, "Invalid expression '#{@content}'") : result
    end

    def argument_to_float(argument, parts)
      if parts.length == 1
        argument.to_f if parts.first.match(DIGIT_PATTERN)
      elsif parts.length == 2
        characteristic = parts.first.match(DIGIT_PATTERN)
        mantissa = parts.last.match(DIGIT_PATTERN)
        argument.to_f if (characteristic and mantissa)
      end
    end
  end

  class FormulaFactory
    ARGUMENTS_ERROR = "Wrong number of arguments for '%s': expected %s"
    FORMULAS = {
      ADD: ->(a, b, *other) { [a, b, other].flatten.reduce(:+) },
      MULTIPLY: ->(a, b, *other) { [a, b, other].flatten.reduce(:*) },
      SUBTRACT: ->(a, b) { a - b },
      DIVIDE: ->(a, b) { a / b },
      MOD: ->(a, b) { a % b },
    }

    class << self
      def calculate(method_name, args)
        @name = method_name
        @formula = FORMULAS[method_name]
        @args = args

        check_number_of_arguments
        format_result @formula.call(*args)
      end

      def check_number_of_arguments
        if @formula.arity > 0 and @formula.arity != @args.size
          raise Error, ARGUMENTS_ERROR %
            [@name, "#{@formula.arity}, got #{@args.size}"]
        elsif @formula.arity < -1 and @formula.arity.abs - 1 > @args.size
          raise Error, ARGUMENTS_ERROR %
            [@name, "at least #{@formula.arity.abs - 1}, got #{@args.size}"]
        end
      end

      def format_result(number)
        number == number.to_i ? number.to_i.to_s : ('%.2f' % number)
      end
    end
  end
end