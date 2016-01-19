module LazyMode
  def self.create_file(name, &block)
    File.new(name, &block)
  end

  class Date
    include Comparable
    PREFIX = '0'
    DAYS_PER_IDENTIFIER = {d: 1, w: 7, m: 30}
    attr_accessor :year, :month, :day, :step

    def initialize(string)
      date = string.split(' ')[0].split('-').map { |s| s.to_i }
      @year = date[0]
      @month = date[1]
      @day = date[2]

      repeat = string.split(' ')[1]
      @step = calculate_step(repeat) if not repeat.nil?
    end

    def <=>(other)
      [@year, @month, @day] <=> [other.year, other.month, other.day]
    end

    def increase_days(step = @step)
      @day += step
      put_in_ranges
      self
    end

    def to_s
      year = add_prefix(@year.to_s, 4, PREFIX)
      month = add_prefix(@month.to_s, 2, PREFIX)
      day = add_prefix(@day.to_s, 2, PREFIX)

      [year, month, day].join('-')
    end

    private

    def add_prefix(string, count, prefix)
      string.rjust(count, prefix)
    end

    def put_in_ranges
      @month += (@day % 30 == 0) ? (@day / 30 - 1) : @day / 30
      @day = (@day % 30 == 0) ? 30 : (@day % 30)

      @year += (@month % 12 == 0) ? (@month / 12 - 1) : @month / 12
      @month = (@month % 12 == 0) ? 12 : (@month % 12)
    end

    def calculate_step(repeat)
      period_identifier = repeat.slice(-1).to_sym
      count = repeat.slice(1..-1).to_i
      DAYS_PER_IDENTIFIER[period_identifier] * count
    end
  end

  class Note
    attr_reader :header, :body, :status, :tags
    attr_reader :file_name, :file
    attr_reader :scheduled, :date

    def initialize(header, file, *tags, &block)
      @header, @file, @tags = header, file, tags
      @file_name = file.name
      @body = ''
      @status = :topostpone

      file.notes << self
      instance_eval &block
    end

    def body(body = nil)
      @body = body if body
      @body
    end

    def scheduled(date = nil)
      if date
        @scheduled = date
        @date = Date.new(date)
      end
      @scheduled
    end

    def status(status = nil)
      @status = status if status
      @status
    end

    def scheduled_for(date)
      while(not @date.step.nil? and date > @date)
        @date.increase_days
      end
      @date == date
    end

    def note(header, *tags, &block)
      new_note = self.class.new(header, @file, *tags, &block)
    end
  end

  class File
    attr_accessor :name, :notes

    def initialize(name, &block)
      @name = name
      @notes = []
      instance_eval &block
    end

    def note(header, *tags, &block)
      new_note = Note.new(header, self, *tags, &block)
    end

    def daily_agenda(date)
      Agenda.new daily_notes(date)
    end

    def weekly_agenda(from)
      week = []
      0.upto(6) { |i| week << from.dup.increase_days(i) }

      weekly_notes = []
      week.each { |day| weekly_notes << daily_notes(day) }
      weekly_notes.flatten!

      Agenda.new weekly_notes
    end

    private

    def daily_notes(date)
      @notes.select { |note| note.scheduled_for(date) }
    end
  end

  class Agenda
    attr_accessor :notes

    def initialize(notes)
      @notes = notes
    end

    def where(status: nil, tag: nil, text: nil)
      notes = @notes.dup
      filter_by_status(notes, status) unless status.nil?
      filter_by_tag(notes, tag) unless tag.nil?
      filter_by_text(notes, text) unless text.nil?

      self.class.new(notes)
    end

    private

    def filter_by_status(notes, status)
      notes.reject! { |note| note.status != status }
    end

    def filter_by_tag(notes, tag)
      notes.reject! { |note| not (note.tags.include? tag) }
    end

    def filter_by_text(notes, text)
      notes.reject! { |note| not (note.header =~ text or note.body =~ text) }
    end
  end
end