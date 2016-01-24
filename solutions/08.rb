class Spreadsheet

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
    raise Error, "Cell '#{index}' does not exist" if cell.nil?
    cell.content
  end

  def [](index)
    cell = @cells.find { |cell| cell.at?(index) }
    raise Error, "Cell '#{index}' does not exist" if cell.nil?
    cell.value
  end

  def to_s
    @rows.map.with_index { |row, index| row_to_s(row) }.
      join("\n")
  end

  private

  def row_to_s(row)
    row.map.with_index { |cell, index| cell.value }.
      join("\t")
  end

  def split_to_cells(table)
    @rows = table.strip.
      split(/\n/).
      map.with_index { |row_data, index| new_row(row_data, index) }

    @cells = @rows.flatten
  end

  def new_row(data, index)
    data.strip.
      split(/\t|  /).
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
      calculate_value @content
    end

    def at?(index)
      @address.index == index
    end

    private

    def calculate_value(content)
      formula = Formula.new(content, @parent)
      formula.value
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
      parts = index.split(/(\d+)/)
      parts.length == 2 and valid_column? parts.first and valid_row? parts.last
    end

    private

    def valid_column?(column_index)
      column_index.
        each_char.
        all? { |ch| 'A' <= ch.to_s and ch.to_s <= 'Z' }
    end

    def valid_row?(row)
      not row.match(/^\d+$/).nil?
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

  module Formulas
    def add(*args)
      check_number_of_arguments(2, args, __callee__.to_s)
      format_result(args.reduce(:+))
    end

    def multiply(*args)
      check_number_of_arguments(2, args, __callee__.to_s)
      format_result(args.reduce(:*))
    end

    def subtract(*args)
      check_exact_number_of_arguments(2, args, __callee__.to_s)
      format_result(args.first - args.last)
    end

    def divide(*args)
      check_exact_number_of_arguments(2, args, __callee__.to_s)
      format_result(args.first / args.last)
    end

    def mod(*args)
      check_exact_number_of_arguments(2, args, __callee__.to_s)
      format_result(args.first % args.last)
    end

    def check_number_of_arguments(required, args, formula_name)
      given = args.flatten!.count
      raise Error, "Wrong number of arguments for '#{formula_name.upcase}': \
expected at least #{required}, got #{given}" unless given >= required
    end

    def check_exact_number_of_arguments(required, args, formula_name)
      given = args.flatten!.count
      raise Error, "Wrong number of arguments for '#{formula_name.upcase}': \
expected #{required}, got #{given}" unless given == required
    end

    def format_result(number)
      number == number.to_i ? number.to_i.to_s : ('%.2f' % number)
    end
  end

  class Formula
    FORMULA_NAME_START_INDEX = 1

    include Formulas

    def initialize(content, table)
      @content = content
      @table = table
    end

    def value
      if formula?
        address = Address.new(@content[1..-1])
        address.valid? ? @table[address.index] : self.send(method_name, args)
      else
        @content
      end
    end

    private

    def formula?
      @content[0] == '='
    end

    def method_name
      case name
      when 'ADD', 'MULTIPLY', 'SUBTRACT', 'DIVIDE', 'MOD' then name.downcase
      else raise Error, "Unknown function '#{name}'"
      end
    end

    def name
      beginning = @content.index('(')
      finish = @content.index(')')

      if beginning.nil? or finish.nil?
        raise Error, "Invalid expression '#{@content[1..-1]}'"
      end

      @content.slice(FORMULA_NAME_START_INDEX..(beginning - 1)).
        to_s
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
        argument.to_f if parts.first.match(/^\d+$/)
      elsif parts.length == 2
        characteristic = parts.first.match(/^\d+$/)
        mantissa = parts.last.match(/^\d+$/)
        argument.to_f if (characteristic and mantissa)
      end
    end
  end
end