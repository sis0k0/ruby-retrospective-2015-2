require 'digest/sha1'

module OperationMessageHelpers
  def success(message, result = nil)
    OperationMessage.new(successful: true, message: message, result: result)
  end

  def error(message)
    OperationMessage.new(successful: false, message: message)
  end
end

class OperationMessage
  attr_reader :message, :result

  def initialize(successful:, message:, result: nil)
    @successful = successful
    @message = message
    @result = result
  end

  def success?
    @successful
  end

  def error?
    not @successful
  end
end

class ObjectStore
  include OperationMessageHelpers

  class Commit
    TIME_FORMAT = '%a %b %-d %H:%M %Y %z'

    attr_reader :index, :date, :message, :hash, :files, :objects
    @@commits_count = 0

    def initialize(message, stage, repository_files)
      @index = @@commits_count
      @date = Time.now
      @message = message
      @files = stage.clone
      @objects = repository_files.values

      @@commits_count += 1
    end

    def hash
      Digest::SHA1.hexdigest "#{@date.strftime(TIME_FORMAT)}#{@message}"
    end

    def changed
      @files[:changed]
    end

    def removed
      @files[:removed]
    end

    def to_s
      name = "Commit #{hash}\n"
      date = "Date: #{@date.strftime(TIME_FORMAT)}\n\n"
      message = "\t#{@message}\n\n"

      name << date << message
    end
  end

  class Branch
    include OperationMessageHelpers

    attr_reader :current

    def initialize
      @current = :master
      @branches = {@current => []}
      @files = {@current => {}}
    end

    def create(name)
      name = name.to_sym

      if @branches.has_key?(name)
        error("Branch #{name} already exists.")
      else
        @branches[name] = @branches[@current].dup
        @files[name] = @files[@current].dup
        success("Created branch #{name}.")
      end
    end

    def checkout(name)
      if @branches.has_key?(name.to_sym)
        @current = name.to_sym
        success("Switched to branch #{name}.")
      else
        error("Branch #{name} does not exist.")
      end
    end

    def remove(name)
      if not @branches.has_key?(name.to_sym)
        error("Branch #{name} does not exist.")
      elsif name.to_sym == @current
        error("Cannot remove current branch.")
      else
        @branches.delete(name.to_sym)
        success("Removed branch #{name}.")
      end
    end

    def list
      message = ""
      @branches.keys.sort.each do |name|
        message << list_prefix(name)
        message << name.to_s << "\n"
      end
      message.chop!

      success(message)
    end

    def commit(message, stage)
      stage[:changed].each { |name, object| @files[@current][name] = object }
      stage[:removed].each { |name, object| @files[@current].delete(name) }

      new_commit = Commit.new(message, stage, @files[@current])
      @branches[@current] << new_commit

      new_commit
    end

    def head
      if @branches[@current].length == 0
        error("Branch #{@current} does not have any commits yet.")
      else
        last_commit = @branches[@current].last
        success(last_commit.message, last_commit)
      end
    end

    def get_file(name)
      @files[@current][name.to_sym]
    end

    def get_commit(hash)
      @branches[@current].find { |commit| commit.hash == hash }
    end

    def checkout_commit(last_commit)
      @files[@current] = last_commit.objects
      @branches[@current].select! { |c| c.index <= last_commit.index }
    end

    def log(branch)
      message = ""
      @branches[branch].sort_by { |commit| commit.index }.
        reverse.
        each { |commit| message << commit.to_s }

      message.strip!
    end

    private
    def list_prefix(branch_name)
      branch_name == :master ? "* " : "  "
    end
  end

  attr_accessor :branch

  class << self
    def init(&block)
      self.new &block
    end
  end

  def initialize(&block)
    @branch = Branch.new
    @stage = {changed: {}, removed: {}}

    if block_given?
      instance_eval &block
    end
  end

  def add(name, object)
    @stage[:changed][name.to_sym] = object
    success("Added #{name} to stage.", object)
  end

  def commit(message)
    if @stage[:changed].length == 0 and @stage[:removed].length == 0
      error("Nothing to commit, working directory clean.")
    else
      new_commit = @branch.commit(message, @stage)
      changed_files = new_commit.changed.length + new_commit.removed.length
      message = "#{message}\n\t#{changed_files} objects changed"

      clear_stage
      success(message, new_commit)
    end
  end

  def remove(name)
    object = @branch.get_file(name)
    if object
      @stage[:removed][name.to_sym] = object
      success("Added #{name} for removal.", object)
    else
      error("Object #{name} is not committed.")
    end
  end

  def checkout(commit_hash)
    head = @branch.get_commit(commit_hash)

    if head
      @branch.checkout_commit(head)
      success("HEAD is now at #{commit_hash}.", head)
    else
      error("Commit #{commit_hash} does not exist.")
    end
  end

  def log(branch = @branch.current)
    log = @branch.log(branch)
    error_message = "Branch #{branch} does not have any commits yet."

    (log and not log.empty?) ? success(log) : error(error_message)
  end

  def head
    @branch.head
  end

  def get(name)
    object = @branch.get_file(name)
    success_message = "Found object #{name}."
    error_message = "Object #{name} is not committed."

    object ? success(success_message, object) : error(error_message)
  end

  private

  def clear_stage
    @stage[:changed].clear
    @stage[:removed].clear
  end
end